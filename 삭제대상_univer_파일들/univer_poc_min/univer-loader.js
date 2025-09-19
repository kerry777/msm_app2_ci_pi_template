/* univer-loader.js (POC version) ... (same content as before) */
(function (global) {
  const STATE = { startedAt: Date.now(), waitingResolvers: [], waitingRejectors: [], timeoutHandle: null };
  function getUniverGlobal() {
    if (global.Univer) return global.Univer;
    if (global.univer && global.univer.Univer) return global.univer.Univer;
    if (global.univerjs && global.univerjs.Univer) return global.univerjs.Univer;
    return undefined;
  }
  function _resolveAllReady() {
    const U = getUniverGlobal();
    if (U) {
      STATE.waitingResolvers.splice(0).forEach((res) => res(U));
      if (STATE.timeoutHandle) clearTimeout(STATE.timeoutHandle);
      STATE.timeoutHandle = null;
      return true;
    }
    return false;
  }
  function observeTaggedScripts() {
    const scripts = Array.from(document.querySelectorAll('script[data-univer]'));
    scripts.forEach((s) => {
      function onLoadOrError(){ _resolveAllReady(); }
      s.addEventListener('load', onLoadOrError, { once: true });
      s.addEventListener('error', onLoadOrError, { once: true });
    });
  }
  async function ensureUniverReady(opts = {}) {
    const timeoutMs = typeof opts.timeoutMs === "number" ? opts.timeoutMs : 15000;
    const U0 = getUniverGlobal();
    if (U0) return U0;
    observeTaggedScripts();
    const waitP = new Promise((resolve, reject) => { STATE.waitingResolvers.push(resolve); STATE.waitingRejectors.push(reject); });
    if (!STATE.timeoutHandle) {
      STATE.timeoutHandle = setTimeout(() => {
        const err = new Error("Univer 라이브러리가 로드되지 않았습니다 (timeout).");
        err.detail = { tried: Array.from(document.querySelectorAll('script[data-univer]')).map(s=>s.src||"(inline)") };
        STATE.waitingRejectors.splice(0).forEach((rej) => rej(err));
      }, timeoutMs);
    }
    if (_resolveAllReady()) return getUniverGlobal();
    return waitP;
  }
  function requireUniver() {
    const U = getUniverGlobal();
    if (!U) throw new Error("Univer가 아직 window에 존재하지 않습니다. ensureUniverReady() 이후에 사용하세요.");
    return U;
  }
  global.UniverLoader = { ensureUniverReady, requireUniver, getUniverGlobal };
})(window);
