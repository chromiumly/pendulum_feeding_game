// Tests for firestore.rules. Run with `npm test` (starts the emulator with a
// demo project, so production data is never touched).
import { after, before, beforeEach, describe, test } from 'node:test';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getCountFromServer,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

const PLAYER = 'k7q2xm9pa4c8r3tw';
const OTHER = 'z9y8x7w6v5u4t3s2';
const UNREGISTERED = 'aaaaaaaaaaaaaaaa';

/** The bests/ key: SHA-256 hex of the player ID, as the app computes it. */
const bestKey = (playerId) =>
  createHash('sha256').update(playerId, 'utf8').digest('hex');

let env;
let db;
let playCount = 0;
const newPlayId = () => `play-${Date.now()}-${playCount++}`;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-pendulum-feeding-game',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // The host's admin script registers IDs; rules do not apply to it.
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'players', PLAYER), {});
    await setDoc(doc(admin, 'players', OTHER), {});
  });
  db = env.unauthenticatedContext().firestore();
});

/**
 * Records a play the way the app does: plays + scores, and bests when
 * [best] is given. Individual fields can be overridden to test the rules.
 */
function recordPlay({
  playerId = PLAYER,
  score = 1200,
  playId = newPlayId(),
  best = { key: bestKey(playerId), value: score },
  play = {},
  scoreDoc = {},
  bestDoc = {},
  withScore = true,
} = {}) {
  const batch = writeBatch(db);
  batch.set(doc(db, 'plays', playId), {
    playerId,
    score,
    createdAt: serverTimestamp(),
    ...play,
  });
  if (withScore) {
    batch.set(doc(db, 'scores', playId), { score, ...scoreDoc });
  }
  if (best) {
    batch.set(doc(db, 'bests', best.key), {
      best: best.value,
      playId,
      ...bestDoc,
    });
  }
  return batch.commit();
}

describe('players', () => {
  test('a player can check their own ID', async () => {
    const snapshot = await assertSucceeds(getDoc(doc(db, 'players', PLAYER)));
    if (!snapshot.exists()) throw new Error('registered ID not found');
    const missing = await assertSucceeds(
      getDoc(doc(db, 'players', UNREGISTERED)),
    );
    if (missing.exists()) throw new Error('unregistered ID found');
  });

  test('IDs cannot be listed or written', async () => {
    await assertFails(getDocs(collection(db, 'players')));
    await assertFails(setDoc(doc(db, 'players', UNREGISTERED), {}));
    await assertFails(deleteDoc(doc(db, 'players', PLAYER)));
  });
});

describe('recording a play', () => {
  test('a first play records plays, scores and bests together', async () => {
    await assertSucceeds(recordPlay());
  });

  test('a play without a new best records plays and scores only', async () => {
    await assertSucceeds(recordPlay({ score: 1500 }));
    await assertSucceeds(recordPlay({ score: 800, best: null }));
  });

  test('an unregistered ID cannot record', async () => {
    await assertFails(recordPlay({ playerId: UNREGISTERED }));
  });

  test('scores must be whole hundreds within range', async () => {
    await assertFails(recordPlay({ score: 1250 }));
    await assertFails(recordPlay({ score: -100 }));
    await assertFails(recordPlay({ score: 100100 }));
    await assertFails(recordPlay({ score: 12.5 }));
  });

  test('createdAt must be the server time', async () => {
    await assertFails(recordPlay({ play: { createdAt: new Date() } }));
  });

  test('no extra fields', async () => {
    await assertFails(recordPlay({ play: { name: 'x' } }));
    await assertFails(recordPlay({ scoreDoc: { playerId: PLAYER } }));
    await assertFails(recordPlay({ bestDoc: { playerId: PLAYER } }));
  });

  test('a play needs its anonymous score, and the score its play', async () => {
    await assertFails(recordPlay({ withScore: false, best: null }));
    await assertFails(
      setDoc(doc(db, 'scores', newPlayId()), { score: 1200 }),
    );
  });

  test('the anonymous score must match the play', async () => {
    await assertFails(recordPlay({ scoreDoc: { score: 5000 } }));
  });

  test('plays cannot be read, changed or deleted', async () => {
    const playId = newPlayId();
    await assertSucceeds(recordPlay({ playId }));
    await assertFails(getDoc(doc(db, 'plays', playId)));
    await assertFails(getDocs(collection(db, 'plays')));
    await assertFails(updateDoc(doc(db, 'plays', playId), { score: 9900 }));
    await assertFails(deleteDoc(doc(db, 'plays', playId)));
  });

  test('a recorded play cannot be recorded again', async () => {
    const playId = newPlayId();
    await assertSucceeds(recordPlay({ playId }));
    await assertFails(recordPlay({ playId, best: null }));
    await assertFails(updateDoc(doc(db, 'scores', playId), { score: 9900 }));
    await assertFails(deleteDoc(doc(db, 'scores', playId)));
  });
});

describe('bests', () => {
  test('the key is the SHA-256 of the player ID (rules compute it)', async () => {
    // Someone else's key, or anything that is not the player's hash, fails.
    await assertFails(
      recordPlay({ best: { key: bestKey(OTHER), value: 1200 } }),
    );
    await assertFails(recordPlay({ best: { key: PLAYER, value: 1200 } }));
    await assertFails(
      recordPlay({
        best: { key: bestKey(PLAYER).toUpperCase(), value: 1200 },
      }),
    );
  });

  test('the best must be the new play score', async () => {
    await assertFails(
      recordPlay({ score: 1200, best: { key: bestKey(PLAYER), value: 9900 } }),
    );
  });

  test('a best can only go up', async () => {
    await assertSucceeds(recordPlay({ score: 1500 }));
    await assertFails(recordPlay({ score: 1500 }));
    await assertFails(recordPlay({ score: 1000 }));
    await assertSucceeds(recordPlay({ score: 1600 }));
  });

  test('a best must come with a new play, not an old one', async () => {
    const playId = newPlayId();
    await assertSucceeds(recordPlay({ playId, score: 1200 }));
    // Re-using the recorded play to set a best without a new play.
    await assertFails(
      setDoc(doc(db, 'bests', bestKey(PLAYER)), { best: 1200, playId }),
    );
  });

  test('bests cannot be deleted', async () => {
    await assertSucceeds(recordPlay());
    await assertFails(deleteDoc(doc(db, 'bests', bestKey(PLAYER))));
  });
});

describe('ranking reads', () => {
  test('scores and bests can be counted, without player IDs', async () => {
    await assertSucceeds(recordPlay({ playerId: PLAYER, score: 1200 }));
    await assertSucceeds(
      recordPlay({ playerId: OTHER, score: 1500 }),
    );
    await assertSucceeds(
      recordPlay({ playerId: PLAYER, score: 700, best: null }),
    );

    const above = await assertSucceeds(
      getCountFromServer(
        query(collection(db, 'scores'), where('score', '>', 1000)),
      ),
    );
    if (above.data().count !== 2) throw new Error(`count ${above.data().count}`);

    const players = await assertSucceeds(
      getCountFromServer(collection(db, 'bests')),
    );
    if (players.data().count !== 2) {
      throw new Error(`players ${players.data().count}`);
    }

    const best = await assertSucceeds(
      getDoc(doc(db, 'bests', bestKey(PLAYER))),
    );
    if (best.data().best !== 1200) throw new Error('best');
  });
});
