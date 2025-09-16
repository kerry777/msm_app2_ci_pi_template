const { chromium } = require('playwright');

async function navigateToTemplateEditor() {
  console.log('🧭 Testing Navigation to Template Editor...\n');
  
  const browser = await chromium.launch({ 
    headless: false,
    slowMo: 1500 // Very slow for debugging
  });
  const page = await browser.newPage();
  
  // Set up error monitoring
  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    if (type === 'error') {
      console.log('❌ Console Error:', text);
    } else if (text.includes('Template') || text.includes('템플릿')) {
      console.log('📝 Template related:', text);
    }
  });
  
  try {
    console.log('[1/5] Loading MSM App...');
    await page.goto('http://localhost/msm/', { waitUntil: 'networkidle' });
    
    console.log('[2/5] Waiting for Flutter to load...');
    await page.waitForSelector('flutter-view', { timeout: 20000 });
    await page.waitForTimeout(3000);
    
    console.log('[3/5] Looking for navigation menu...');
    
    // Try to find menu items or navigation
    const menuSelectors = [
      'text="주문/납품"', // Order/Delivery menu category
      'text="Template Editor"',
      'text="Template"',
      'text="템플릿"',
      'text="Editor"',
      'text="편집기"',
      'button:has-text("Template")',
      'button:has-text("Editor")',
      'button:has-text("주문")',
      'button:has-text("납품")'
    ];
    
    let menuFound = false;
    for (const selector of menuSelectors) {
      try {
        console.log(`   Trying: ${selector}`);
        const element = await page.locator(selector).first();
        if (await element.isVisible()) {
          console.log(`✅ Found menu element: ${selector}`);
          await element.click();
          await page.waitForTimeout(2000);
          menuFound = true;
          break;
        }
      } catch (e) {
        // Continue to next selector
      }
    }
    
    if (!menuFound) {
      console.log('❌ No obvious menu found, trying to explore page content...');
      
      // Take screenshot of current state
      await page.screenshot({ path: 'menu_search.png' });
      console.log('📸 Screenshot saved as menu_search.png');
      
      // Look for any clickable elements with text
      const clickables = await page.locator('button, [role="button"], a, [tabindex], .clickable').all();
      console.log(`🔍 Found ${clickables.length} potentially clickable elements:`);
      
      for (let i = 0; i < Math.min(clickables.length, 15); i++) {
        try {
          const text = await clickables[i].textContent();
          const visible = await clickables[i].isVisible();
          const enabled = await clickables[i].isEnabled();
          if (text && text.trim() && visible && enabled) {
            console.log(`  Clickable ${i}: "${text.trim()}" (${visible ? 'visible' : 'hidden'}, ${enabled ? 'enabled' : 'disabled'})`);
          }
        } catch (e) {
          // Skip this element
        }
      }
    }
    
    console.log('[4/5] Looking for Template Editor specifically...');
    
    // Now look for template editor specific elements
    const templateSelectors = [
      'text="Template Editor"',
      'text="ej2_spreadsheet"',
      'text="EJ2"',
      '[data-test="template"]',
      '[data-test="editor"]',
      '#template',
      '#templateSelect',
      'select[id*="template"]',
      'button[onclick*="loadTemplate"]'
    ];
    
    let templateFound = false;
    for (const selector of templateSelectors) {
      try {
        console.log(`   Looking for: ${selector}`);
        const elements = await page.locator(selector).count();
        if (elements > 0) {
          console.log(`✅ Found ${elements} template elements with: ${selector}`);
          templateFound = true;
          
          // Try to interact with it
          const element = await page.locator(selector).first();
          if (await element.isVisible() && await element.isEnabled()) {
            console.log(`🖱️ Clicking template element...`);
            await element.click();
            await page.waitForTimeout(3000);
          }
        }
      } catch (e) {
        // Continue
      }
    }
    
    console.log('[5/5] Final check for template interface...');
    
    // Final check for any template loading interface
    await page.waitForTimeout(2000);
    
    const finalCheck = await page.evaluate(() => {
      // Check for template-related content in the page
      const bodyText = document.body.innerText || '';
      const hasTemplate = bodyText.includes('Template') || bodyText.includes('템플릿');
      const hasSpreadsheet = bodyText.includes('Spreadsheet') || bodyText.includes('스프레드시트');
      const hasSelect = document.querySelector('select') !== null;
      const hasEJ2 = bodyText.includes('EJ2') || bodyText.includes('Syncfusion');
      
      return {
        hasTemplate,
        hasSpreadsheet,
        hasSelect,
        hasEJ2,
        pageText: bodyText.substring(0, 500) // First 500 chars for debugging
      };
    });
    
    console.log('📊 Final check results:', finalCheck);
    
    // Take final screenshot
    await page.screenshot({ path: 'final_template_search.png' });
    console.log('📸 Final screenshot saved as final_template_search.png');
    
    const success = templateFound || finalCheck.hasTemplate || finalCheck.hasEJ2;
    
    console.log('\n' + '='.repeat(60));
    console.log('🎯 NAVIGATION TEST RESULTS:');
    console.log('='.repeat(60));
    console.log(`Menu Navigation: ${menuFound ? '✅ FOUND' : '❌ NOT FOUND'}`);
    console.log(`Template Editor: ${templateFound ? '✅ FOUND' : '❌ NOT FOUND'}`);
    console.log(`Template Content: ${finalCheck.hasTemplate ? '✅ FOUND' : '❌ NOT FOUND'}`);
    console.log(`EJ2/Syncfusion: ${finalCheck.hasEJ2 ? '✅ FOUND' : '❌ NOT FOUND'}`);
    
    if (success) {
      console.log('\n✅ SUCCESS: Template editor interface accessible');
    } else {
      console.log('\n❌ FAILURE: Cannot access template editor');
      console.log('🔧 Next steps:');
      console.log('   1. Check Flutter routing configuration');
      console.log('   2. Verify ej2_spreadsheet_debug screen is properly enabled');
      console.log('   3. Check if direct URL navigation is possible');
    }
    
    return success;
    
  } catch (error) {
    console.log('❌ Navigation test failed:', error.message);
    return false;
  } finally {
    await browser.close();
  }
}

navigateToTemplateEditor();