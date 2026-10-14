(() => {
  const params = new URLSearchParams(location.search);
  const video = document.querySelector('#video');
  const state = document.querySelector('#state');
  const preview = params.get('preview') === '1';
  let hls = null;
  let finished = false;
  let timeout;
  let url;
  function fail() {
    if (finished && preview) return;
    clearTimeout(timeout);
    if (hls) { hls.destroy(); hls = null; }
    video.pause();
    video.removeAttribute('src');
    state.hidden = false;
    document.querySelector('#message').textContent = 'Prévia indisponível';
    document.querySelector('#hint').textContent = 'A câmera não respondeu no momento';
  }
  try {
    url = new URL(params.get('stream'));
    if (!['http:', 'https:'].includes(url.protocol) || (location.protocol === 'https:' && url.protocol !== 'https:')) throw Error();
  } catch { fail(); return; }
  video.controls = !preview;
  video.addEventListener('loadeddata', () => {
    finished = true;
    clearTimeout(timeout);
    state.hidden = true;
    if (preview) {
      video.pause();
      if (hls) hls.stopLoad();
    } else {
      video.play().catch(() => {});
    }
  });
  video.addEventListener('error', fail);
  timeout = setTimeout(fail, 18000);
  if (window.Hls && Hls.isSupported()) {
    hls = new Hls({enableWorker: true, maxBufferLength: preview ? 2 : 10,
      manifestLoadingMaxRetry: 0, levelLoadingMaxRetry: 0, fragLoadingMaxRetry: 0});
    hls.on(Hls.Events.ERROR, (_, data) => { if (data.fatal) fail(); });
    hls.loadSource(url.href);
    hls.attachMedia(video);
  } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
    video.src = url.href;
    video.load();
  } else { fail(); }
  window.addEventListener('pagehide', () => {
    clearTimeout(timeout);
    video.pause();
    if (hls) hls.destroy();
  });
})();
