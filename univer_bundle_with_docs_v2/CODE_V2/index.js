// index.js (V2) — Robust resolver for various UMD layouts
(function () {
  function logNS(label, obj) {
    try {
      const keys = obj && typeof obj === 'object' ? Object.keys(obj) : [];
      console.log(`🔍 ${label}:`, obj ? (obj.constructor && obj.constructor.name) : obj, 'keys=', keys);
    } catch (e) {
      console.log(`🔍 ${label}:`, obj, '(keys not enumerable)');
    }
  }

  console.log("🚀 MSM Excel 시스템 시작");
  console.log("=== Univer 간단 초기화 시작 ===");

  // 1) Raw candidates
  const U = window.Univer || window.UNIVER || {};
  const coreCandidates = [
    window.UniverCore,
    U.core, U.Core,
    U.core && U.core.default,
    U.Core && U.Core.default,
  ].filter(Boolean);

  const sheetsCandidates = [
    window.UniverSheets,
    U.sheets, U.Sheets,
    U.sheets && U.sheets.default,
  ].filter(Boolean);

  const sheetsUiCandidates = [
    window.UniverSheetsUi, window.UniverSheetsUI,
    U.sheetsUi, U.sheetsUI, U.SheetsUI,
    U['sheets-ui'], U['Sheets-UI'],
    (U.ui && (U.ui.sheets || U.ui.Sheets)),
  ].filter(Boolean);

  const Core = coreCandidates[0];
  const SheetsNS = sheetsCandidates[0];
  const SheetsUiNS = sheetsUiCandidates[0];

  logNS('Univer (root)', U);
  logNS('UniverCore candidate', Core);
  logNS('UniverSheets candidate', SheetsNS);
  logNS('UniverSheetsUi candidate', SheetsUiNS);

  if (!Core || !SheetsNS || !SheetsUiNS) {
    console.error("필수 네임스페이스(Core/Sheets/SheetsUI) 탐지 실패", { Core: !!Core, Sheets: !!SheetsNS, SheetsUI: !!SheetsUiNS });
    return;
  }
  console.log("✅ 네임스페이스 후보 확인 완료");

  // 2) Extract symbols with fallbacks
  const LocaleType = Core.LocaleType || Core.locale?.LocaleType || Core.Locales || Core.LOCALE || null;
  const UniverCtor = Core.Univer || Core.default?.Univer || Core.Core?.Univer || null;
  const Tools = Core.Tools || Core.utils || Core.Helpers || null;
  const InstanceType = Core.UniverInstanceType || Core.InstanceType || null;

  logNS('LocaleType', LocaleType);
  logNS('Univer (ctor)', UniverCtor);
  logNS('Tools', Tools);
  logNS('UniverInstanceType', InstanceType);

  // 3) Locale resolve
  let localeValue = null;
  if (LocaleType && (LocaleType.EN_US || LocaleType['enUS'] || LocaleType['en-US'])) {
    localeValue = LocaleType.EN_US || LocaleType['enUS'] || LocaleType['en-US'];
    console.log('🌐 LocaleType resolved:', localeValue);
  } else {
    console.warn('⚠️ LocaleType을 찾지 못했습니다. 기본 로캘로 진행합니다.');
  }

  // 4) Constructor guard
  if (typeof UniverCtor !== 'function') {
    console.error('Univer 생성자를 찾지 못했습니다. Core 네임스페이스 구조가 다른 버전일 수 있습니다.');
    return;
  }

  try {
    // 5) Create Univer instance
    const univer = new UniverCtor(localeValue ? { locale: localeValue } : {});

    // 6) Register plugins
    const SheetsPlugin = SheetsNS.UniverSheetsPlugin || SheetsNS.default?.UniverSheetsPlugin;
    const SheetsUIPlugin = SheetsUiNS.UniverSheetsUIPlugin || SheetsUiNS.default?.UniverSheetsUIPlugin;

    if (!SheetsPlugin || !SheetsUIPlugin) {
      console.error('Sheets/SheetsUI 플러그인 클래스를 찾지 못했습니다.', { SheetsPlugin: !!SheetsPlugin, SheetsUIPlugin: !!SheetsUIPlugin });
      return;
    }

    univer.registerPlugin(SheetsPlugin);

    const container = document.getElementById("app");
    if (!container) throw new Error("#app 컨테이너를 찾을 수 없습니다.");
    univer.registerPlugin(SheetsUIPlugin, { container });

    // 7) Create a workbook
    const safeId = (Tools && typeof Tools.generateRandomId === "function")
      ? Tools.generateRandomId(6)
      : Math.random().toString(36).slice(2, 8);

    const unitId = "book_" + safeId;
    const sheetType = (InstanceType && InstanceType.UNIVER_SHEET) || "UNIVER_SHEET";

    univer.createUnit(sheetType, {
      id: unitId,
      name: "Book1",
      sheets: [{ id: "sheet1", name: "Sheet1", rowCount: 100, columnCount: 26 }],
    });

    console.log("✅ Univer 초기화 완료 (V2)");
  } catch (err) {
    console.error("Univer 초기화 실패(V2):", err);
    console.log("Available Univer-like objects:", Object.keys(window).filter(k => /Univer/i.test(k)));
  }
})();
