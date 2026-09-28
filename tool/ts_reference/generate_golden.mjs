// Generates golden data for the double-pendulum physics from the TypeScript
// prototype (../pendulum-feeding-game), which is treated as read-only.
//
// The TS sources are transpiled in memory with the prototype's own
// `typescript` package; `phaser` is replaced by a minimal Vector2 stub so the
// real `Pendulum` class (RK4 + dynamics + positions) runs under Node.
//
// Usage (from the Flutter project root):
//   node tool/ts_reference/generate_golden.mjs
// Output: test/fixtures/pendulum_golden.json

import { createRequire } from "node:module";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const projectRoot = resolve(here, "../..");
const tsRoot = resolve(projectRoot, "../pendulum-feeding-game");
const tsGame = join(tsRoot, "src/game");

const require = createRequire(join(tsRoot, "package.json"));
const ts = require("typescript");

const sources = {
  "PendulumConfig": "objects/pendulum/PendulumConfig.ts",
  "PendulumDynamics": "objects/pendulum/PendulumDynamics.ts",
  "RK4": "objects/pendulum/RK4.ts",
  "Pendulum": "objects/pendulum/Pendulum.ts",
  "GameSceneConfig": "scenes/game/GameSceneConfig.ts",
};

const phaserStub = `
class Vector2 {
  constructor(x = 0, y = 0) { this.x = x; this.y = y; }
}
export default { Math: { Vector2 } };
`;

const outDir = mkdtempSync(join(tmpdir(), "pendulum-ts-ref-"));
writeFileSync(join(outDir, "phaser.mjs"), phaserStub);

for (const [name, rel] of Object.entries(sources)) {
  const src = readFileSync(join(tsGame, rel), "utf8");
  let js = ts.transpileModule(src, {
    compilerOptions: {
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
      useDefineForClassFields: true,
    },
  }).outputText;
  js = js
    .replace(/from\s+["']phaser["']/g, 'from "./phaser.mjs"')
    .replace(/from\s+["']\.\/(\w+)["']/g, 'from "./$1.mjs"');
  writeFileSync(join(outDir, `${name}.mjs`), js);
}

const load = (name) => import(pathToFileURL(join(outDir, `${name}.mjs`)).href);
const { PendulumConfig } = await load("PendulumConfig");
const { PendulumDynamics } = await load("PendulumDynamics");
const { Pendulum } = await load("Pendulum");
const { GameSceneConfig } = await load("GameSceneConfig");

const initial = GameSceneConfig.pendulum;
const origin = { x: initial.origin.x, y: initial.origin.y };

function simulate(dts) {
  const pendulum = new Pendulum(
    initial.upperTheta,
    initial.lowerTheta,
    initial.upperOmega,
    initial.lowerOmega,
  );
  const frames = [];
  const record = (dt) => {
    const { upperPosition, lowerPosition } = pendulum.getPositions(origin);
    frames.push({
      dt,
      state: [
        pendulum.upperTheta,
        pendulum.lowerTheta,
        pendulum.upperOmega,
        pendulum.lowerOmega,
      ],
      upper: [upperPosition.x, upperPosition.y],
      lower: [lowerPosition.x, lowerPosition.y],
    });
  };
  record(0);
  for (const dt of dts) {
    pendulum.update(dt);
    record(dt);
  }
  return frames;
}

// Deterministic pseudo-random dt sequence (mulberry32) in [1/120, 1/30].
function variableDts(count, seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return Array.from({ length: count }, () => 1 / 120 + next() * (1 / 30 - 1 / 120));
}

const derivativeStates = [
  [3 * Math.PI / 4, Math.PI / 2, 0, 0],
  [0, 0, 0, 0],
  [0.3, 0.3, 1.2, -0.7],
  [Math.PI, 0, 0, 0],
  [-2.5, 1.7, 5.0, -8.0],
  [10.0, -10.0, 20.0, 30.0],
  [1e-9, -1e-9, 1e-6, 0],
];

const golden = {
  generatedBy: "tool/ts_reference/generate_golden.mjs",
  params: {
    upperMass: PendulumConfig.upperMass,
    lowerMass: PendulumConfig.lowerMass,
    upperLength: PendulumConfig.upperLength,
    lowerLength: PendulumConfig.lowerLength,
    gravityAcceleration: PendulumConfig.gravityAcceleration,
  },
  initial: {
    origin: [origin.x, origin.y],
    state: [initial.upperTheta, initial.lowerTheta, initial.upperOmega, initial.lowerOmega],
  },
  derivatives: derivativeStates.map((state) => ({
    state,
    derivative: PendulumDynamics.derivatives(state),
  })),
  trajectories: {
    // 20 s at the fixed game step.
    fixed60: simulate(Array.from({ length: 1200 }, () => 1 / 60)),
    // Variable frame times like the Phaser prototype.
    variable: simulate(variableDts(600, 20240923)),
  },
};

const outPath = join(projectRoot, "test/fixtures/pendulum_golden.json");
writeFileSync(outPath, JSON.stringify(golden) + "\n");
console.log(`wrote ${outPath}`);
