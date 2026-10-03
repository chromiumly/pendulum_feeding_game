// Starts the game, and moves the loading screen's bar as it starts.
//
// This is Flutter's own start-up script with the loading screen added
// (flutter build fills in its template parts). Flutter does not say how many
// bytes of the game it has fetched, so the bar goes by the stages of the
// start instead: it jumps to the start of each stage when it is reached, and
// creeps towards the end of the stage meanwhile, never reaching it. Only the
// game's first frame brings it to the end.

{{flutter_js}}
{{flutter_build_config}}

(function () {
  const screen = document.getElementById('loading');
  const bar = document.getElementById('loading-bar');
  const label = document.getElementById('loading-label');

  // The stages, in percent of the bar: where each begins, and the most the
  // creeping reaches before the next one.
  const stages = {
    fetching: { from: 4, to: 42 }, // The page's files are on their way.
    loaded: { from: 46, to: 72 }, // The game's code is here; the engine starts.
    started: { from: 76, to: 90 }, // The engine is up; the game starts.
    running: { from: 92, to: 98 }, // The game runs; waiting for a frame.
  };

  let stage = stages.fetching;
  let target = stage.from; // Where the bar is heading.
  let shown = 0; // Where the bar is.
  let finished = false;

  function enter(next) {
    stage = next;
    target = Math.max(target, next.from);
  }

  // Each frame: creep the target on, and ease the bar towards it.
  function frame() {
    if (finished) return;
    target += (stage.to - target) * 0.004;
    shown += (target - shown) * 0.08;
    bar.style.width = shown.toFixed(1) + '%';
    requestAnimationFrame(frame);
  }
  requestAnimationFrame(frame);

  // The game drew its first frame: fill the bar, then fade the screen away.
  function finish() {
    if (finished) return;
    finished = true;
    bar.style.width = '100%';
    setTimeout(function () {
      screen.classList.add('done');
      setTimeout(function () { screen.remove(); }, 600);
    }, 250);
  }
  window.addEventListener('flutter-first-frame', finish);

  // A slow start is not a stuck one, but it is worth a word.
  setTimeout(function () {
    if (finished) return;
    label.textContent =
      '読み込みに時間がかかっています。電波のよい場所で、このまま少しお待ちください。';
  }, 30000);

  _flutter.loader.load({
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
      enter(stages.loaded);
      const appRunner = await engineInitializer.initializeEngine();
      enter(stages.started);
      await appRunner.runApp();
      enter(stages.running);
    },
  });
})();
