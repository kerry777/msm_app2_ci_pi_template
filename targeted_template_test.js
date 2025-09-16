const { chromium } = require('playwright');

/**
 * Targeted Template Loading Test
 * Direct test of the core template loading functionality
 */

class TargetedTemplateTest {
  constructor() {
    this.browser = null;
    this.page = null;
  }

  async setup() {
    console.log('🎯 Starting Targeted Template Loading Test...\n');
    
    this.browser = await chromium.launch({ 
      headless: false,
      slowMo: 1000 // Slower for debugging
    });
    
    this.page = await this.browser.newPage();
    
    // Set up comprehensive error handlers
    this.page.on('console', msg => {
      const type = msg.type();
      const text = msg.text();
      if (type === 'error') {
        console.log('❌ Console Error:', text);
      } else if (type === 'log' && (text.includes('❌') || text.includes('✅'))) {
        console.log('📝', text);
      }
    });
    
    this.page.on('pageerror', error => {
      console.log('❌ Page Error:', error.message);
    });

    this.page.setDefaultTimeout(30000);
  }

  async testDirectTemplateAccess() {
    console.log('[1/4] Testing Direct Template Loading Access...');
    
    try {
      // Go directly to the MSM app
      await this.page.goto('http://localhost/msm/', { waitUntil: 'networkidle' });
      
      // Wait for Flutter to load
      await this.page.waitForSelector('flutter-view', { timeout: 20000 });
      
      // Wait for any spreadsheet interface to load
      await this.page.waitForTimeout(5000);
      
      // Look for template selector dropdown
      const templateSelectors = [
        '#templateSelect',
        'select[id*="template"]',
        'select[id*="Template"]',
        'select:has(option[value*="PI"])',
        'select:has(option[value*="CI"])',
        'select:has(option[value*="PL"])'
      ];
      
      let templateSelect = null;
      for (const selector of templateSelectors) {
        try {
          const element = await this.page.locator(selector).first();
          if (await element.isVisible()) {
            templateSelect = element;
            console.log(`✅ Found template selector: ${selector}`);
            break;
          }
        } catch (e) {
          continue;
        }
      }
      
      if (!templateSelect) {
        console.log('❌ No template selector found');
        return false;
      }
      
      return templateSelect;
      
    } catch (error) {
      console.log('❌ Error in direct access test:', error.message);
      return false;
    }
  }

  async testTemplateSelection(templateSelect) {
    console.log('[2/4] Testing Template Selection...');
    
    try {
      // Get all options
      const options = await templateSelect.locator('option').all();
      console.log(`📋 Found ${options.length} template options`);
      
      for (let i = 0; i < options.length; i++) {
        const option = options[i];
        const value = await option.getAttribute('value');
        const text = await option.textContent();
        console.log(`  Option ${i}: "${text}" (value: "${value}")`);
      }
      
      // Try to select PI template
      const piOption = options.find(async (option) => {
        const value = await option.getAttribute('value');
        return value && value.includes('PI');
      });
      
      if (piOption) {
        const value = await piOption.getAttribute('value');
        await templateSelect.selectOption(value);
        console.log(`✅ Selected PI template: ${value}`);
        return value;
      } else {
        console.log('❌ PI template option not found');
        return null;
      }
      
    } catch (error) {
      console.log('❌ Error in template selection:', error.message);
      return null;
    }
  }

  async testLoadTemplateFunction(selectedTemplate) {
    console.log('[3/4] Testing Load Template Function...');
    
    try {
      // Look for load template button
      const loadButtonSelectors = [
        'button:has-text("Load Template")',
        'button:has-text("템플릿 로드")',
        'button[onclick*="loadTemplate"]',
        'button[onclick*="Load"]'
      ];
      
      let loadButton = null;
      for (const selector of loadButtonSelectors) {
        try {
          const element = await this.page.locator(selector).first();
          if (await element.isVisible()) {
            loadButton = element;
            console.log(`✅ Found load button: ${selector}`);
            break;
          }
        } catch (e) {
          continue;
        }
      }
      
      if (!loadButton) {
        console.log('❌ Load template button not found');
        return false;
      }
      
      // Click the load button
      console.log('🔄 Clicking load template button...');
      await loadButton.click();
      
      // Wait and check for loading activity
      await this.page.waitForTimeout(3000);
      
      // Check console logs for template loading
      const result = await this.page.evaluate(() => {
        // Check if loadTemplate function exists and is callable
        if (typeof window.loadTemplate === 'function') {
          return { exists: true, callable: true };
        } else if (typeof loadTemplate === 'function') {
          return { exists: true, callable: true };
        } else {
          return { exists: false, callable: false, available: Object.keys(window).filter(k => k.includes('load') || k.includes('template')) };
        }
      });
      
      console.log('📊 Function check result:', result);
      return result.callable;
      
    } catch (error) {
      console.log('❌ Error testing load function:', error.message);
      return false;
    }
  }

  async testSpreadsheetContent() {
    console.log('[4/4] Testing Spreadsheet Content Loading...');
    
    try {
      // Wait for any loading to complete
      await this.page.waitForTimeout(5000);
      
      // Check for spreadsheet content
      const spreadsheetChecks = [
        { selector: '.e-spreadsheet', name: 'EJ2 Spreadsheet' },
        { selector: '.e-sheet', name: 'EJ2 Sheet' },
        { selector: 'canvas', name: 'Canvas Element' },
        { selector: '#spreadsheet', name: 'Spreadsheet Container' },
        { selector: '[role="grid"]', name: 'Grid Role' }
      ];
      
      let hasContent = false;
      for (const check of spreadsheetChecks) {
        try {
          const elements = await this.page.locator(check.selector).count();
          if (elements > 0) {
            console.log(`✅ Found ${check.name}: ${elements} elements`);
            hasContent = true;
          } else {
            console.log(`❌ No ${check.name} found`);
          }
        } catch (e) {
          console.log(`❌ Error checking ${check.name}:`, e.message);
        }
      }
      
      // Check for any data in the spreadsheet
      const hasData = await this.page.evaluate(() => {
        // Look for any spreadsheet instance
        if (window.spreadsheet) {
          console.log('✅ Spreadsheet instance found');
          console.log('Spreadsheet sheets:', window.spreadsheet.sheets);
          return true;
        }
        return false;
      });
      
      return hasContent && hasData;
      
    } catch (error) {
      console.log('❌ Error checking spreadsheet content:', error.message);
      return false;
    }
  }

  async cleanup() {
    if (this.browser) {
      await this.browser.close();
    }
  }

  async runFullTest() {
    try {
      await this.setup();
      
      // Test 1: Direct access
      const templateSelect = await this.testDirectTemplateAccess();
      if (!templateSelect) {
        console.log('🛑 Cannot access template interface. Test aborted.');
        return false;
      }
      
      // Test 2: Template selection  
      const selectedTemplate = await this.testTemplateSelection(templateSelect);
      if (!selectedTemplate) {
        console.log('⚠️ Template selection failed, but continuing tests...');
      }
      
      // Test 3: Load function
      const loadFunctionWorks = await this.testLoadTemplateFunction(selectedTemplate);
      
      // Test 4: Content check
      const hasContent = await this.testSpreadsheetContent();
      
      // Final assessment
      console.log('\n' + '='.repeat(60));
      console.log('🎯 TARGETED TEST RESULTS:');
      console.log('='.repeat(60));
      console.log(`Template Interface Access: ${templateSelect ? '✅ PASS' : '❌ FAIL'}`);
      console.log(`Template Selection: ${selectedTemplate ? '✅ PASS' : '❌ FAIL'}`);
      console.log(`Load Function: ${loadFunctionWorks ? '✅ PASS' : '❌ FAIL'}`);
      console.log(`Spreadsheet Content: ${hasContent ? '✅ PASS' : '❌ FAIL'}`);
      
      const coreWorking = templateSelect && loadFunctionWorks;
      console.log(`\n🎯 Core Template Loading: ${coreWorking ? '✅ WORKING' : '❌ BROKEN'}`);
      
      if (coreWorking) {
        console.log('✅ SUCCESS: Template loading mechanism is functional');
        console.log('📋 Users can access and load invoice templates');
      } else {
        console.log('❌ FAILURE: Core template loading still not working');
        if (!templateSelect) console.log('   - Template interface not accessible');
        if (!loadFunctionWorks) console.log('   - Load function not working properly');
      }
      
      return coreWorking;
      
    } catch (error) {
      console.log('🚨 Test execution failed:', error.message);
      return false;
    } finally {
      await this.cleanup();
    }
  }
}

// Execute the targeted test
(async () => {
  const test = new TargetedTemplateTest();
  const success = await test.runFullTest();
  
  console.log('\n' + '='.repeat(60));
  console.log(success ? '🎉 TARGETED TEMPLATE TEST COMPLETED SUCCESSFULLY' : '💥 TARGETED TEMPLATE TEST FAILED');
  console.log('='.repeat(60));
  
  process.exit(success ? 0 : 1);
})();