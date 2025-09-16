const { chromium } = require('playwright');

async function verifyTemplateLoad() {
  console.log('🎯 Verifying Actual Template Loading...\n');
  
  const browser = await chromium.launch({ 
    headless: false,
    slowMo: 1500 
  });
  const page = await browser.newPage();
  
  // 콘솔 로그 캡처
  const logs = [];
  page.on('console', msg => {
    const text = msg.text();
    logs.push(`${msg.type()}: ${text}`);
    if (text.includes('Template') || text.includes('템플릿') || text.includes('loading') || text.includes('error')) {
      console.log(`📋 Console: ${msg.type()}: ${text}`);
    }
  });
  
  try {
    console.log('[1/5] Loading template editor...');
    await page.goto('http://localhost/msm/template_editor_direct.html');
    await page.waitForTimeout(5000);
    
    console.log('[2/5] Taking BEFORE screenshot...');
    await page.screenshot({ path: 'before_template_load.png' });
    
    // 스프레드시트가 비어있는지 확인
    const beforeContent = await page.evaluate(() => {
      const spreadsheetDiv = document.querySelector('#spreadsheet');
      if (!spreadsheetDiv) return 'No spreadsheet found';
      
      // EJ2 스프레드시트 내용 확인
      const cells = document.querySelectorAll('.e-cell');
      let cellContent = '';
      for (let i = 0; i < Math.min(10, cells.length); i++) {
        const text = cells[i].textContent || cells[i].innerText;
        if (text && text.trim()) {
          cellContent += `Cell ${i}: "${text.trim()}" `;
        }
      }
      return cellContent || 'Spreadsheet appears empty';
    });
    
    console.log(`📊 BEFORE loading: ${beforeContent}`);
    
    console.log('[3/5] Selecting PI template and clicking load...');
    
    // PI 템플릿 선택
    await page.locator('#templateSelect').selectOption('MEK_SALES_TEMPLATE_PI.xlsx');
    await page.waitForTimeout(1000);
    
    // Load 버튼 클릭
    await page.locator('button:has-text("Load Template")').click();
    console.log('✅ Load button clicked');
    
    // 로딩 대기 (좀 더 길게)
    await page.waitForTimeout(8000);
    
    console.log('[4/5] Checking if content changed...');
    
    // 로딩 후 내용 확인
    const afterContent = await page.evaluate(() => {
      const spreadsheetDiv = document.querySelector('#spreadsheet');
      if (!spreadsheetDiv) return 'No spreadsheet found';
      
      // EJ2 스프레드시트 내용 다시 확인
      const cells = document.querySelectorAll('.e-cell');
      let cellContent = '';
      let nonEmptyCells = 0;
      
      for (let i = 0; i < Math.min(20, cells.length); i++) {
        const text = cells[i].textContent || cells[i].innerText;
        if (text && text.trim()) {
          cellContent += `Cell ${i}: "${text.trim()}" `;
          nonEmptyCells++;
        }
      }
      
      // 추가로 특정 텍스트 확인
      const bodyText = document.body.innerText;
      const hasProforma = bodyText.includes('PROFORMA') || bodyText.includes('Invoice');
      const hasPI = bodyText.includes('PI-') || bodyText.includes('Proforma');
      
      return {
        cellContent: cellContent || 'No cell content found',
        nonEmptyCells,
        hasProforma,
        hasPI,
        totalCells: cells.length
      };
    });
    
    console.log(`📊 AFTER loading:`, afterContent);
    
    // 상태바 확인
    try {
      const statusText = await page.textContent('#statusBar', { timeout: 1000 });
      console.log(`📊 Status Bar: "${statusText}"`);
    } catch (e) {
      console.log('📊 No status bar found');
    }
    
    console.log('[5/5] Taking AFTER screenshot...');
    await page.screenshot({ path: 'after_template_load.png' });
    
    // 결과 분석
    const contentChanged = afterContent.nonEmptyCells > 0 || 
                          afterContent.hasProforma || 
                          afterContent.hasPI;
    
    console.log('\n' + '='.repeat(60));
    console.log('🎯 TEMPLATE LOADING VERIFICATION RESULTS:');
    console.log('='.repeat(60));
    console.log(`Before Loading: "${beforeContent}"`);
    console.log(`After Loading: Non-empty cells: ${afterContent.nonEmptyCells}`);
    console.log(`Content Changed: ${contentChanged ? '✅ YES' : '❌ NO'}`);
    console.log(`Has Proforma Content: ${afterContent.hasProforma ? '✅ YES' : '❌ NO'}`);
    console.log(`Has PI Content: ${afterContent.hasPI ? '✅ YES' : '❌ NO'}`);
    
    if (contentChanged) {
      console.log('\n✅ SUCCESS: 템플릿이 실제로 로드되었습니다!');
      console.log('Template content loaded successfully!');
    } else {
      console.log('\n❌ ISSUE: 템플릿이 로드되지 않았습니다.');
      console.log('Template loading may have failed. Check console logs above.');
    }
    
    // 콘솔 로그 요약
    if (logs.length > 0) {
      console.log('\n📋 All Console Logs:');
      logs.forEach(log => console.log(`   ${log}`));
    }
    
    return contentChanged;
    
  } catch (error) {
    console.log('❌ Verification failed:', error.message);
    await page.screenshot({ path: 'template_verify_error.png' });
    return false;
  } finally {
    // 수동 확인을 위해 대기
    console.log('\n⏸️ Browser kept open for manual inspection...');
    console.log('수동으로 스프레드시트 내용을 확인해보세요.');
    
    await new Promise(resolve => {
      console.log('Press Enter to close...');
      process.stdin.once('data', () => {
        browser.close();
        resolve();
      });
    });
  }
}

verifyTemplateLoad();