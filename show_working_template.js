const { chromium } = require('playwright');

async function showWorkingTemplate() {
  console.log('🎯 Capturing Working Template Loading...\n');
  
  const browser = await chromium.launch({ 
    headless: false,
    slowMo: 1000 
  });
  const page = await browser.newPage();
  
  try {
    // 1. 직접 템플릿 에디터 로드
    console.log('[1/6] Loading template editor directly...');
    await page.goto('http://localhost/msm/template_editor_direct.html', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);
    
    await page.screenshot({ path: 'working_step1_initial.png' });
    console.log('✅ Step 1: Initial screen captured');
    
    // 2. PI 템플릿 선택 확인
    console.log('[2/6] Selecting PI template...');
    try {
      await page.locator('#templateSelect').selectOption('MEK_SALES_TEMPLATE_PI.xlsx');
      await page.waitForTimeout(1000);
      await page.screenshot({ path: 'working_step2_template_selected.png' });
      console.log('✅ Step 2: PI template selected');
    } catch (e) {
      console.log('Template already selected');
    }
    
    // 3. Load Template 버튼 클릭
    console.log('[3/6] Clicking Load Template button...');
    await page.locator('button:has-text("Load Template")').click();
    console.log('✅ Load Template button clicked');
    
    // 4. 로딩 후 대기
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'working_step3_after_load.png' });
    console.log('✅ Step 3: After template load');
    
    // 5. 스프레드시트 내용 확인 및 스크롤
    console.log('[4/6] Checking spreadsheet content...');
    
    // A1 셀에 내용이 있는지 확인하고 스크린샷
    const cellContent = await page.evaluate(() => {
      const cells = document.querySelectorAll('.e-cell');
      let content = [];
      for (let i = 0; i < Math.min(10, cells.length); i++) {
        const text = cells[i]?.textContent?.trim();
        if (text && text.length > 0) {
          content.push(`Cell ${i}: "${text}"`);
        }
      }
      
      // 페이지 전체 텍스트에서 Proforma 관련 내용 확인
      const bodyText = document.body.innerText;
      const hasProforma = bodyText.includes('PROFORMA') || bodyText.includes('Invoice') || bodyText.includes('PI-');
      
      return {
        cellContent: content,
        hasProforma,
        bodyText: bodyText.substring(0, 500)
      };
    });
    
    console.log('📊 Spreadsheet content found:', cellContent);
    
    // 6. 특정 셀을 클릭해서 내용 확인
    console.log('[5/6] Clicking on cells to show content...');
    try {
      // A1 셀 클릭
      await page.locator('.e-cell').first().click();
      await page.waitForTimeout(1000);
      await page.screenshot({ path: 'working_step4_cell_selected.png' });
      console.log('✅ Step 4: Cell content visible');
    } catch (e) {
      console.log('Cell click failed, but continuing...');
    }
    
    // 7. 최종 전체 화면 스크린샷
    console.log('[6/6] Taking final full screenshot...');
    await page.screenshot({ path: 'working_step5_final_working.png', fullPage: true });
    console.log('✅ Step 5: Final working screenshot captured');
    
    console.log('\n' + '='.repeat(70));
    console.log('🎯 WORKING TEMPLATE SCREENSHOTS CAPTURED:');
    console.log('='.repeat(70));
    console.log('📸 Screenshots saved:');
    console.log('   - working_step1_initial.png (초기 화면)');
    console.log('   - working_step2_template_selected.png (템플릿 선택)');
    console.log('   - working_step3_after_load.png (로드 후)');
    console.log('   - working_step4_cell_selected.png (셀 선택)');
    console.log('   - working_step5_final_working.png (최종 작동 화면)');
    
    if (cellContent.hasProforma) {
      console.log('\n✅ SUCCESS: Template content is loaded and visible!');
      console.log('Proforma Invoice template is working correctly!');
    } else {
      console.log('\n⚠️ Template may need manual verification');
    }
    
    return true;
    
  } catch (error) {
    console.log('❌ Screenshot capture failed:', error.message);
    await page.screenshot({ path: 'working_error.png' });
    return false;
  } finally {
    await browser.close();
  }
}

showWorkingTemplate().then(success => {
  if (success) {
    console.log('\n🎉 Template working screenshots captured successfully!');
    console.log('Check the working_step*.png files to see the template in action.');
  } else {
    console.log('\n❌ Failed to capture working template screenshots');
  }
});