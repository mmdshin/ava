// Custom Flutter web bootstrap (Flutter fills in the {{…}} tokens at
// build time). It differs from Flutter's default in one way: instead of
// Flutter's own service worker (which no longer caches anything since
// Flutter 3.41), it registers AvA's offline worker, ava_sw.js.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();

(function registerOfflineWorker() {
  if (!('serviceWorker' in navigator)) return;

  // Not during `flutter run` (debug builds load hundreds of dev files).
  var builds = (_flutter.buildConfig && _flutter.buildConfig.builds) || [];
  var isDebug = builds.some(function (b) {
    return b.compileTarget === 'dartdevc';
  });
  if (isDebug) return;

  window.addEventListener('load', function () {
    navigator.serviceWorker.register('ava_sw.js').then(function (reg) {
      // The first visit loaded everything before the worker existed.
      // Hand it the list of files this page already used (engine, fonts,
      // content), so they are cached and the next visit works offline.
      function sendUsedFiles(worker) {
        if (!worker) return;
        var urls = performance.getEntriesByType('resource').map(function (e) {
          return e.name;
        });
        urls.push(location.href.split('#')[0]);
        worker.postMessage({ type: 'cache-urls', urls: urls });
      }
      if (reg.active) {
        sendUsedFiles(reg.active);
      } else {
        var installing = reg.installing || reg.waiting;
        if (installing) {
          installing.addEventListener('statechange', function () {
            if (installing.state === 'activated') sendUsedFiles(installing);
          });
        }
      }
    }).catch(function (err) {
      console.warn('AvA offline worker not registered:', err);
    });
  });
})();
