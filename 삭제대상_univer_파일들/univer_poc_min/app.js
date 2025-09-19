(function () {
  const logEl = document.getElementById('log');
  const appEl = document.getElementById('app');
  const fileEl = document.getElementById('file');

  function log(msg, cls) {
    const line = document.createElement('div');
    if (cls) line.className = cls;
    line.textContent = msg;
    logEl.appendChild(line);
    (cls === 'err' ? console.error : console.log)(msg);
  }

  async function boot() {
    log("🚀 초기화 시작");
    try {
      log("⏳ Univer 로딩 대기중...");
      const Univer = await window.UniverLoader.ensureUniverReady({ timeoutMs: 15000 });
      log("✅ Univer global 확인됨", "ok");

      // 안전한 영역: 여기서부터 Univer API 사용 가능
      const mount = document.createElement('div');
      mount.textContent = "여기에 Univer 워크북 초기화 코드를 넣으세요.";
      appEl.appendChild(mount);
    } catch (err) {
      log("❌ Univer 초기화 실패: " + (err && err.message ? err.message : err), "err");
      // 폴백: 간단한 테이블 생성(에러 없음)
      const table = document.createElement('table');
      table.border = "1";
      table.innerHTML = "<tr><th>제품</th><th>수량</th><th>금액</th></tr><tr><td>샘플</td><td>1</td><td>1000</td></tr>";
      appEl.appendChild(table);
      log("✅ 대체 테이블 생성 완료", "ok");
    }
  }

  // 파일 선택(POC): Univer가 준비되지 않아도 에러 없이 동작 (실제 파싱은 구현하지 않음)
  fileEl.addEventListener('change', (e) => {
    const f = e.target.files && e.target.files[0];
    if (!f) return;
    log(`📂 파일 선택: ${f.name} (${f.size} bytes)`);
  });

  boot();
})();