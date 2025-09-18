// index.js (Fixed minimal bootstrap for Univer UMD)
/* global UniverCore, UniverSheets, UniverSheetsUi */
(function () {
  console.log("🚀 MSM Excel 시스템 시작");
  console.log("=== Univer 간단 초기화 시작 ===");

  // 1) UMD 전역 존재 여부 확인
  const hasCore = typeof window.UniverCore !== "undefined";
  const hasSheets = typeof window.UniverSheets !== "undefined";
  const hasSheetsUi = typeof window.UniverSheetsUi !== "undefined";

  if (!hasCore || !hasSheets || !hasSheetsUi) {
    console.error("필수 UMD 전역(UniverCore/UniverSheets/UniverSheetsUi) 중 일부가 없습니다.", {
      hasCore, hasSheets, hasSheetsUi, available: Object.keys(window)
    });
    return;
  }
  console.log("✅ 모듈 확인 완료");

  try {
    // 2) 정확한 네임스페이스에서 필요한 심볼을 가져옵니다.
    const { LocaleType, Univer, Tools, UniverInstanceType } = UniverCore;

    if (!LocaleType || typeof LocaleType.EN_US === "undefined") {
      throw new Error("LocaleType.EN_US 가 없습니다. (버전/로드 순서를 확인하세요)");
    }

    // 3) Univer 인스턴스 생성
    const univer = new Univer({
      locale: LocaleType.EN_US,
    });

    // 4) 시트 & UI 플러그인 등록
    univer.registerPlugin(UniverSheets.UniverSheetsPlugin);

    const container = document.getElementById("app");
    if (!container) throw new Error("#app 컨테이너를 찾을 수 없습니다.");
    univer.registerPlugin(UniverSheetsUi.UniverSheetsUIPlugin, { container });

    // 5) 워크북(Unit) 생성 - 최소 렌더링용
    const safeId = (Tools && typeof Tools.generateRandomId === "function")
      ? Tools.generateRandomId(6)
      : Math.random().toString(36).slice(2, 8);

    const unitId = "book_" + safeId;
    const sheetType = (UniverInstanceType && UniverInstanceType.UNIVER_SHEET) || "UNIVER_SHEET";

    univer.createUnit(sheetType, {
      id: unitId,
      name: "Book1",
      sheets: [{ id: "sheet1", name: "Sheet1", rowCount: 100, columnCount: 26 }],
    });

    console.log("✅ Univer 초기화 완료");
  } catch (err) {
    console.error("Univer 초기화 실패:", err);
    console.log("Available Univer objects: ", Object.keys(window).filter(k => /^Univer/.test(k)));
  }
})();
