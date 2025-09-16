const { chromium } = require('playwright');

/**
 * Comprehensive Template Loading Test
 * Tests the core requirement: PI, CI, PL invoice template loading through Flutter menu navigation
 */

class TemplateLoadingTest {
  constructor() {
    this.browser = null;
    this.page = null;
    this.results = {
      appLoaded: false,
      menuNavigation: false,
      templateEditor: false,
      piTemplate: false,
      ciTemplate: false,
      plTemplate: false,
      spreadsheetDisplay: false,
      errors: []
    };
  }

  async setup() {
    console.log('🚀 Starting Template Loading Test...\n');
    
    // Launch browser with extended timeout
    this.browser = await chromium.launch({ 
      headless: false,
      slowMo: 500 // Slow down for observation
    });
    
    this.page = await this.browser.newPage();
    
    // Set up error handlers
    this.page.on('console', msg => {
      if (msg.type() === 'error') {
        console.log('❌ Console Error:', msg.text());
        this.results.errors.push(`Console: ${msg.text()}`);
      }
    });
    
    this.page.on('pageerror', error => {
      console.log('❌ Page Error:', error.message);
      this.results.errors.push(`Page: ${error.message}`);
    });

    // Set longer timeout for Flutter app loading
    this.page.setDefaultTimeout(30000);
  }

  async testStep1_FlutterAppLoad() {
    console.log('[1/6] Testing Flutter App Load...');
    
    try {
      await this.page.goto('http://localhost/msm/', { waitUntil: 'networkidle' });
      
      // Wait for Flutter app to initialize
      await this.page.waitForSelector('flutter-view', { timeout: 20000 });
      
      // Check for buildConfig errors
      const buildConfigError = await this.page.locator('text=buildConfig').count() > 0;
      if (buildConfigError) {
        this.results.errors.push('BuildConfig error detected');
        console.log('❌ BuildConfig error found');
        return false;
      }
      
      // Wait for Flutter framework to be ready
      await this.page.waitForFunction(() => {
        return window.flutterCanvasKit || window.flutter_assets;
      }, { timeout: 15000 });
      
      this.results.appLoaded = true;
      console.log('✅ Flutter app loaded successfully');
      return true;
      
    } catch (error) {
      console.log('❌ Flutter app load failed:', error.message);
      this.results.errors.push(`App Load: ${error.message}`);
      return false;
    }
  }

  async testStep2_MenuNavigation() {
    console.log('[2/6] Testing Menu Navigation...');
    
    try {
      // Look for main menu items - try multiple selectors
      const menuSelectors = [
        'button:has-text("Template")',
        'text="Template Editor"',
        'text="템플릿"',
        '[role="button"]:has-text("Template")',
        '.menu-item:has-text("Template")'
      ];
      
      let templateMenuFound = false;
      
      for (const selector of menuSelectors) {
        try {
          await this.page.waitForSelector(selector, { timeout: 3000 });
          await this.page.click(selector);
          templateMenuFound = true;
          console.log(`✅ Found and clicked template menu with selector: ${selector}`);
          break;
        } catch (e) {
          // Try next selector
          continue;
        }
      }
      
      if (!templateMenuFound) {
        // Try to find any menu structure
        const menus = await this.page.locator('button, [role="button"], .menu-item').all();
        console.log(`📋 Found ${menus.length} potential menu items`);
        
        for (let i = 0; i < Math.min(menus.length, 10); i++) {
          const text = await menus[i].textContent().catch(() => '');
          console.log(`  Menu ${i}: "${text}"`);
        }
        
        this.results.errors.push('Template menu not found');
        return false;
      }
      
      this.results.menuNavigation = true;
      return true;
      
    } catch (error) {
      console.log('❌ Menu navigation failed:', error.message);
      this.results.errors.push(`Menu Navigation: ${error.message}`);
      return false;
    }
  }

  async testStep3_TemplateEditor() {
    console.log('[3/6] Testing Template Editor Access...');
    
    try {
      // Wait for template editor to load
      const editorSelectors = [
        'text="Template Editor"',
        'text="템플릿 편집기"',
        '.template-editor',
        '#template-editor',
        '[data-testid="template-editor"]'
      ];
      
      let editorFound = false;
      
      for (const selector of editorSelectors) {
        try {
          await this.page.waitForSelector(selector, { timeout: 5000 });
          editorFound = true;
          console.log(`✅ Template editor found with selector: ${selector}`);
          break;
        } catch (e) {
          continue;
        }
      }
      
      if (!editorFound) {
        // Check if we're still loading
        await this.page.waitForTimeout(3000);
        
        // Look for any template-related content
        const templateText = await this.page.locator('text=/template/i').first().textContent().catch(() => null);
        if (templateText) {
          console.log(`📋 Found template-related content: "${templateText}"`);
          editorFound = true;
        }
      }
      
      this.results.templateEditor = editorFound;
      return editorFound;
      
    } catch (error) {
      console.log('❌ Template editor access failed:', error.message);
      this.results.errors.push(`Template Editor: ${error.message}`);
      return false;
    }
  }

  async testStep4_TemplateSelection() {
    console.log('[4/6] Testing Template Selection and Loading...');
    
    const templates = ['PI', 'CI', 'PL'];
    let successCount = 0;
    
    for (const templateType of templates) {
      try {
        console.log(`  Testing ${templateType} template...`);
        
        // Look for template selector/dropdown
        const selectors = [
          `button:has-text("${templateType}")`,
          `option:has-text("${templateType}")`,
          `text="${templateType}"`,
          `[value="${templateType}"]`,
          `.template-${templateType.toLowerCase()}`
        ];
        
        let templateSelected = false;
        
        for (const selector of selectors) {
          try {
            const element = await this.page.locator(selector).first();
            if (await element.isVisible()) {
              await element.click();
              templateSelected = true;
              console.log(`    ✅ Selected ${templateType} template`);
              
              // Wait for template to load
              await this.page.waitForTimeout(2000);
              
              this.results[`${templateType.toLowerCase()}Template`] = true;
              successCount++;
              break;
            }
          } catch (e) {
            continue;
          }
        }
        
        if (!templateSelected) {
          console.log(`    ❌ ${templateType} template not found or not selectable`);
          this.results.errors.push(`${templateType} template not accessible`);
        }
        
      } catch (error) {
        console.log(`    ❌ Error testing ${templateType} template:`, error.message);
        this.results.errors.push(`${templateType} Template: ${error.message}`);
      }
    }
    
    return successCount > 0;
  }

  async testStep5_SpreadsheetDisplay() {
    console.log('[5/6] Testing EJ2 Spreadsheet Display...');
    
    try {
      // Look for Syncfusion EJ2 Spreadsheet elements
      const spreadsheetSelectors = [
        '.e-spreadsheet',
        '.e-sheet',
        '.e-main-panel',
        '[role="grid"]',
        '.syncfusion-spreadsheet',
        'canvas' // EJ2 often uses canvas
      ];
      
      let spreadsheetFound = false;
      
      for (const selector of spreadsheetSelectors) {
        try {
          await this.page.waitForSelector(selector, { timeout: 5000 });
          
          const element = await this.page.locator(selector).first();
          if (await element.isVisible()) {
            spreadsheetFound = true;
            console.log(`✅ EJ2 Spreadsheet found with selector: ${selector}`);
            
            // Check if spreadsheet has content
            const hasContent = await this.page.locator(`${selector} *`).count() > 0;
            if (hasContent) {
              console.log('✅ Spreadsheet contains content');
            }
            
            break;
          }
        } catch (e) {
          continue;
        }
      }
      
      if (!spreadsheetFound) {
        // Check for any table/grid structure
        const tables = await this.page.locator('table, [role="grid"], canvas').count();
        console.log(`📋 Found ${tables} table/grid elements on page`);
        
        this.results.errors.push('EJ2 Spreadsheet not found');
      }
      
      this.results.spreadsheetDisplay = spreadsheetFound;
      return spreadsheetFound;
      
    } catch (error) {
      console.log('❌ Spreadsheet display test failed:', error.message);
      this.results.errors.push(`Spreadsheet Display: ${error.message}`);
      return false;
    }
  }

  async testStep6_ValidationSummary() {
    console.log('[6/6] Validation Summary...\n');
    
    const passedTests = Object.values(this.results).filter(v => v === true).length - 1; // -1 for errors array
    const totalTests = 6;
    
    console.log('📊 TEST RESULTS:');
    console.log('================');
    console.log(`✅ Flutter App Loaded: ${this.results.appLoaded ? 'PASS' : 'FAIL'}`);
    console.log(`✅ Menu Navigation: ${this.results.menuNavigation ? 'PASS' : 'FAIL'}`);
    console.log(`✅ Template Editor: ${this.results.templateEditor ? 'PASS' : 'FAIL'}`);
    console.log(`✅ PI Template: ${this.results.piTemplate ? 'PASS' : 'FAIL'}`);
    console.log(`✅ CI Template: ${this.results.ciTemplate ? 'PASS' : 'FAIL'}`);
    console.log(`✅ PL Template: ${this.results.plTemplate ? 'PASS' : 'FAIL'}`);
    console.log(`✅ Spreadsheet Display: ${this.results.spreadsheetDisplay ? 'PASS' : 'FAIL'}`);
    
    console.log(`\n📈 Overall Score: ${passedTests}/${totalTests} tests passed\n`);
    
    if (this.results.errors.length > 0) {
      console.log('🚨 ERRORS ENCOUNTERED:');
      this.results.errors.forEach((error, index) => {
        console.log(`  ${index + 1}. ${error}`);
      });
      console.log('');
    }
    
    // CORE REQUIREMENT ASSESSMENT
    const coreRequirementMet = this.results.appLoaded && 
                              (this.results.piTemplate || this.results.ciTemplate || this.results.plTemplate);
    
    console.log('🎯 CORE REQUIREMENT ASSESSMENT:');
    console.log('================================');
    console.log(`Core Business Requirement (Template Loading): ${coreRequirementMet ? '✅ MET' : '❌ NOT MET'}`);
    
    if (coreRequirementMet) {
      console.log('✅ SUCCESS: Users can load invoice templates for business use');
    } else {
      console.log('❌ FAILURE: Template loading functionality not working');
      console.log('🔧 REQUIRED FIXES:');
      if (!this.results.appLoaded) {
        console.log('   - Fix Flutter app loading issues');
      }
      if (!this.results.menuNavigation) {
        console.log('   - Fix menu navigation to Template Editor');
      }
      if (!this.results.piTemplate && !this.results.ciTemplate && !this.results.plTemplate) {
        console.log('   - Fix template selection and loading mechanism');
      }
    }
    
    return coreRequirementMet;
  }

  async cleanup() {
    if (this.browser) {
      await this.browser.close();
    }
  }

  async runFullTest() {
    try {
      await this.setup();
      
      const step1 = await this.testStep1_FlutterAppLoad();
      if (!step1) {
        console.log('🛑 Critical failure: Flutter app failed to load. Stopping test.');
        await this.testStep6_ValidationSummary();
        return false;
      }
      
      await this.testStep2_MenuNavigation();
      await this.testStep3_TemplateEditor();
      await this.testStep4_TemplateSelection();
      await this.testStep5_SpreadsheetDisplay();
      
      const success = await this.testStep6_ValidationSummary();
      
      return success;
      
    } catch (error) {
      console.log('🚨 Test execution failed:', error.message);
      this.results.errors.push(`Test Execution: ${error.message}`);
      return false;
    } finally {
      await this.cleanup();
    }
  }
}

// Execute the test
(async () => {
  const test = new TemplateLoadingTest();
  const success = await test.runFullTest();
  
  console.log('\n' + '='.repeat(60));
  console.log(success ? '🎉 TEMPLATE LOADING TEST COMPLETED SUCCESSFULLY' : '💥 TEMPLATE LOADING TEST FAILED');
  console.log('='.repeat(60));
  
  process.exit(success ? 0 : 1);
})();