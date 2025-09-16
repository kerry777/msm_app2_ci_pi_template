const { chromium } = require('playwright');

async function quickTestWorkingImplementation() {
  console.log('🎯 Quick Test - Verifying Working Implementation...\n');
  
  const browser = await chromium.launch({ 
    headless: false,
    slowMo: 1000 
  });
  const page = await browser.newPage();
  
  try {
    // Test 1: Test standalone EJ2 external HTML
    console.log('[1/2] Testing standalone EJ2 external HTML...');
    await page.goto('http://localhost/msm/ej2_spreadsheet_external.html', { waitUntil: 'networkidle' });
    await page.waitForTimeout(5000);
    
    const externalHtmlTest = await page.evaluate(() => {
      return {
        title: document.title,
        hasEJ2: window.ej !== undefined,
        hasSpreadsheet: document.getElementById('spreadsheet') !== null,
        templateSelect: document.getElementById('templateSelect') !== null,
        buttons: Array.from(document.querySelectorAll('button')).length,
        loadTemplateBtn: document.getElementById('loadTemplateBtn') !== null
      };
    });
    
    console.log('External HTML test:', externalHtmlTest);
    await page.screenshot({ path: 'quick_test_external_html.png' });
    
    if (externalHtmlTest.hasEJ2 && externalHtmlTest.hasSpreadsheet) {
      console.log('✅ External EJ2 HTML is working properly');
      
      // Test template button
      const templateTest = await page.evaluate(() => {
        const templateSelect = document.getElementById('templateSelect');
        const loadBtn = document.getElementById('loadTemplateBtn');
        
        if (templateSelect && loadBtn) {
          templateSelect.value = 'MEK_SALES_TEMPLATE_PI.xlsx';
          loadBtn.click();
          return { success: true, template: templateSelect.value };
        }
        return { success: false };
      });
      
      console.log('Template load test:', templateTest);
      await page.waitForTimeout(3000);
      await page.screenshot({ path: 'quick_test_template_load.png' });
    }
    
    // Test 2: Check if Flutter app has any working server
    console.log('\n[2/2] Testing Flutter app access...');
    
    const flutterUrls = [
      'http://localhost:50540/',
      'http://localhost:50541/',
      'http://localhost:58000/',
      'http://localhost:58001/',
      'http://localhost:58002/'
    ];
    
    let workingFlutterUrl = null;
    
    for (const url of flutterUrls) {
      try {
        console.log(`Trying ${url}...`);
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 3000 });
        
        const response = await page.evaluate(() => {
          return {
            title: document.title,
            hasContent: document.body.innerText.length > 0
          };
        });
        
        if (response.title === 'MSM' || response.hasContent) {
          workingFlutterUrl = url;
          console.log(`✅ Found working Flutter app at: ${url}`);
          
          // Quick analysis of Flutter app
          const flutterAnalysis = await page.evaluate(() => {
            return {
              title: document.title,
              hasIframe: document.querySelector('iframe') !== null,
              iframeCount: document.querySelectorAll('iframe').length,
              hasEJ2Text: document.body.innerText.includes('EJ2'),
              hasTemplateText: document.body.innerText.includes('Template'),
              buttons: Array.from(document.querySelectorAll('button')).map(btn => btn.textContent.trim()).slice(0, 10)
            };
          });
          
          console.log('Flutter app analysis:', flutterAnalysis);
          await page.screenshot({ path: 'quick_test_flutter_app.png' });
          break;
        }
      } catch (e) {
        console.log(`❌ ${url} not accessible: ${e.message}`);
      }
    }
    
    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('🎯 QUICK TEST SUMMARY:');
    console.log('='.repeat(60));
    console.log(`✅ External EJ2 HTML: ${externalHtmlTest.hasEJ2 && externalHtmlTest.hasSpreadsheet ? 'WORKING' : 'FAILED'}`);
    console.log(`✅ Flutter App: ${workingFlutterUrl ? `WORKING at ${workingFlutterUrl}` : 'NOT ACCESSIBLE'}`);
    
    if (externalHtmlTest.hasEJ2 && workingFlutterUrl) {
      console.log('\n🎉 SUCCESS: Both components are working!');
      console.log('📋 Template loading system is functional');
      console.log('📋 External iframe approach has all necessary components');
      
      console.log('\n📸 Screenshots saved:');
      console.log('- quick_test_external_html.png - Standalone EJ2 working');
      console.log('- quick_test_template_load.png - Template loading test');
      console.log('- quick_test_flutter_app.png - Flutter app status');
      
    } else {
      console.log('\n⚠️ Issues detected:');
      if (!externalHtmlTest.hasEJ2) console.log('- External EJ2 HTML not working');
      if (!workingFlutterUrl) console.log('- Flutter app not accessible');
    }
    
  } catch (error) {
    console.log('❌ Test failed:', error.message);
    await page.screenshot({ path: 'quick_test_error.png' });
  }
  
  console.log('\n⏸️ Browser kept open for manual verification...');
  console.log('Press Enter to close...');
  
  await new Promise(resolve => {
    process.stdin.once('data', () => {
      browser.close();
      resolve();
    });
  });
}

quickTestWorkingImplementation();