const { chromium } = require('playwright');

async function directTemplateTest() {
  console.log('🎯 Testing Direct EJ2 Template Loading...\n');
  
  const browser = await chromium.launch({ 
    headless: false,
    slowMo: 2000 
  });
  const page = await browser.newPage();
  
  const screenshots = [];
  
  try {
    // 1. MSM 앱 직접 로드 (EJ2 화면으로 바로)
    console.log('[1/5] Loading MSM App (Direct to EJ2)...');
    await page.goto('http://localhost/msm/', { waitUntil: 'networkidle' });
    await page.waitForTimeout(8000); // EJ2 로딩 대기
    
    await page.screenshot({ path: 'direct_step1_ej2_loaded.png' });
    screenshots.push('direct_step1_ej2_loaded.png - EJ2 화면 직접 로드');
    
    // 2. 템플릿 선택 드롭다운 확인
    console.log('[2/5] Checking template selection dropdown...');
    
    try {
      const dropdown = await page.locator('#templateSelect').first();
      if (await dropdown.isVisible()) {
        console.log('✅ Template dropdown found');
        
        // PI 템플릿 선택
        await dropdown.selectOption('MEK_SALES_TEMPLATE_PI.xlsx');
        console.log('✅ PI template selected');
        
        await page.waitForTimeout(2000);
        await page.screenshot({ path: 'direct_step2_template_selected.png' });
        screenshots.push('direct_step2_template_selected.png - PI 템플릿 선택');
      }
    } catch (e) {
      console.log('드롭다운 선택 실패:', e.message);
    }
    
    // 3. Load Template 버튼 클릭
    console.log('[3/5] Clicking Load Template button...');
    
    try {
      const loadButton = await page.locator('button:has-text("Load Template")').first();
      if (await loadButton.isVisible()) {
        console.log('✅ Found load button');
        await loadButton.click();
        console.log('✅ Load button clicked');
        
        await page.waitForTimeout(5000); // 템플릿 로딩 대기
        await page.screenshot({ path: 'direct_step3_load_clicked.png' });
        screenshots.push('direct_step3_load_clicked.png - 로드 버튼 클릭 후');
      }
    } catch (e) {
      console.log('로드 버튼 클릭 실패:', e.message);
    }
    
    // 4. 템플릿 로드 결과 확인
    console.log('[4/5] Checking if template loaded...');
    
    const templateContent = await page.evaluate(() => {
      // 스프레드시트 내용 확인
      const spreadsheet = document.querySelector('#spreadsheet, .e-spreadsheet');
      if (!spreadsheet) return { found: false, reason: 'No spreadsheet element' };
      
      const cells = document.querySelectorAll('.e-cell');
      let contentCells = 0;
      let sampleContent = '';
      
      for (let i = 0; i < Math.min(50, cells.length); i++) {
        const text = cells[i]?.textContent?.trim();
        if (text && text.length > 0) {
          contentCells++;
          if (sampleContent.length < 200) {
            sampleContent += `"${text}" `;
          }
        }
      }
      
      const bodyText = document.body.innerText;
      const hasProformaText = bodyText.includes('PROFORMA') || 
                             bodyText.includes('Invoice') ||
                             bodyText.includes('PI-');
      
      return {
        found: contentCells > 0 || hasProformaText,
        contentCells,
        sampleContent,
        hasProformaText,
        totalCells: cells.length
      };
    });
    
    console.log('📊 Template content check:', templateContent);
    
    await page.screenshot({ path: 'direct_step4_template_result.png' });
    screenshots.push('direct_step4_template_result.png - 템플릿 로드 결과');
    
    // 5. 최종 결과 스크린샷
    console.log('[5/5] Taking final screenshot...');
    await page.screenshot({ path: 'direct_step5_final.png' });
    screenshots.push('direct_step5_final.png - 최종 결과');
    
    // 결과 요약
    console.log('\n' + '='.repeat(70));
    console.log('🎯 DIRECT EJ2 TEMPLATE LOADING TEST RESULTS:');
    console.log('='.repeat(70));
    console.log(`Template Content Loaded: ${templateContent.found ? '✅' : '❌'}`);
    console.log(`Content Cells: ${templateContent.contentCells}`);
    console.log(`Has Proforma Text: ${templateContent.hasProformaText ? '✅' : '❌'}`);
    console.log(`Sample Content: ${templateContent.sampleContent}`);
    
    console.log('\n📸 Screenshots taken:');
    screenshots.forEach(desc => console.log(`   - ${desc}`));
    
    if (templateContent.found) {
      console.log('\n✅ SUCCESS: 직접 EJ2 화면에서 템플릿 로드가 성공했습니다!');
    } else {
      console.log('\n❌ ISSUE: 템플릿 로드에 문제가 있습니다.');
    }
    
  } catch (error) {
    console.log('❌ Test failed:', error.message);
    await page.screenshot({ path: 'direct_error.png' });
  }
  
  // 수동 확인을 위해 대기
  console.log('\n⏸️ Browser kept open for manual inspection...');
  console.log('실제 템플릿 로드 상태를 확인해보세요.');
  
  await new Promise(resolve => {
    console.log('Press Enter to close...');
    process.stdin.once('data', () => {
      browser.close();
      resolve();
    });
  });
}

directTemplateTest();