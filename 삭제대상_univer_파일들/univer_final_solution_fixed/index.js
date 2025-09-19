// index.js - Univer 0.10.8 Fixed Initialization
(function () {
  console.log("🚀 페이지 로드 완료 - Univer 초기화 시작");

  const container = document.getElementById("app");

  if (!window.UniverCore) {
    console.error("❌ UniverCore 없음");
    return;
  }

  const { createUniver, LocaleType, CommandService } = UniverCore;
  const univer = createUniver({ locale: LocaleType.EN_US });
  console.log("✅ Univer 인스턴스 생성 완료");

  // Register required plugins
  univer.registerPlugin(UniverSheets.UniverSheetsPlugin);
  univer.registerPlugin(UniverSheetsUi.UniverSheetsUIPlugin, { container });
  univer.registerPlugin(UniverSheetsFormula.UniverSheetsFormulaPlugin);
  univer.registerPlugin(UniverSheetsFormulaUi.UniverSheetsFormulaUIPlugin);
  univer.registerPlugin(UniverSheetsNumfmt.UniverSheetsNumfmtPlugin);
  univer.registerPlugin(UniverSheetsNumfmtUi.UniverSheetsNumfmtUIPlugin);
  console.log("✅ 모든 플러그인 등록 완료");

  // Create workbook
  const workbook = univer.createUnit("UNIVER_SHEET", {
    id: "book1",
    name: "Book1",
    sheets: [
      {
        id: "sheet1",
        name: "Sheet1",
        rowCount: 20,
        columnCount: 10,
      },
    ],
  });
  console.log("✅ 워크북 생성 완료", workbook);

  // Activate workbook via CommandService
  try {
    const commandService = univer.__getInjector().get(CommandService);
    commandService.executeCommand("univer.workbook.activate", { unitId: "book1" });
    console.log("✅ 워크북 활성화 명령 실행");
  } catch (e) {
    console.warn("⚠️ 워크북 활성화 실패:", e);
  }
})();
