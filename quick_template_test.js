const { chromium } = require('playwright');

async function quickTemplateTest() {
  console.log('🎯 Quick Template Loading Test...\n');
  
  const browser = await chromium.launch({ 
    headless: false,
    slowMo: 1000 
  });
  const page = await browser.newPage();
  
  try {
    // 직접 템플릿 에디터 접근
    console.log('[1/3] Loading template editor...');
    await page.goto('http://localhost/msm/template_editor_direct.html');
    await page.waitForTimeout(5000);
    
    console.log('[2/3] Testing template selection and load...');
    
    // 템플릿 선택
    try {
      const templateSelect = await page.locator('#templateSelect');
      if (await templateSelect.isVisible()) {
        console.log('✅ Template dropdown found');
        
        // PI 템플릿 선택
        await templateSelect.selectOption('MEK_SALES_TEMPLATE_PI.xlsx');
        console.log('✅ Selected PI template');
        await page.waitForTimeout(1000);
        
        // Load 버튼 클릭
        const loadButton = await page.locator('button:has-text("템플릿 로드")');
        if (await loadButton.isVisible()) {
          console.log('✅ Load button found');
          await loadButton.click();
          console.log('✅ Clicked load button');
          await page.waitForTimeout(3000);
          
          // 결과 확인
          const status = await page.textContent('#statusBar');
          console.log('📊 Status:', status);
          
        } else {
          console.log('❌ Load button not found');
        }
      } else {
        console.log('❌ Template dropdown not found');
      }
    } catch (e) {
      console.log('❌ Template test failed:', e.message);
    }
    
    console.log('[3/3] Taking screenshot...');
    await page.screenshot({ path: 'quick_template_test.png' });
    
    console.log('\n⏸️ Manual test time - check if template loaded...');
    
  } catch (error) {
    console.log('❌ Test failed:', error.message);
  }
  
  // 수동 확인을 위해 대기
  await new Promise(resolve => {
    console.log('Press Enter to close...');
    process.stdin.once('data', () => {
      browser.close();
      resolve();
    });
  });
}

quickTemplateTest();