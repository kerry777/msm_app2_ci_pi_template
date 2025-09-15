// EJ2 Spreadsheet Debug Console Script
// Run these commands in browser console (F12) to diagnose the current issue

console.log('🔍 EJ2 Spreadsheet Debug Console Started');
console.log('=====================================');

// 1. Check EJ2 library loading status
console.log('\n1. EJ2 Library Loading Status:');
console.log('typeof ej:', typeof ej);
if (typeof ej !== 'undefined') {
    console.log('✅ EJ2 main library loaded');
    console.log('ej keys:', Object.keys(ej));
    
    console.log('\n2. EJ2 Spreadsheet Module:');
    console.log('typeof ej.spreadsheet:', typeof ej.spreadsheet);
    if (ej.spreadsheet) {
        console.log('✅ Spreadsheet module available');
        console.log('ej.spreadsheet keys:', Object.keys(ej.spreadsheet));
        
        console.log('\n3. Spreadsheet Constructor:');
        console.log('typeof ej.spreadsheet.Spreadsheet:', typeof ej.spreadsheet.Spreadsheet);
        if (ej.spreadsheet.Spreadsheet) {
            console.log('✅ Spreadsheet constructor available');
            console.log('Constructor prototype:', ej.spreadsheet.Spreadsheet.prototype);
        } else {
            console.log('❌ Spreadsheet constructor NOT available');
        }
    } else {
        console.log('❌ Spreadsheet module NOT available');
    }
} else {
    console.log('❌ EJ2 main library NOT loaded');
    
    // Check if scripts are in DOM
    const scripts = document.querySelectorAll('script[src*="ej2"]');
    console.log('EJ2 scripts in DOM:', scripts.length);
    scripts.forEach((script, i) => {
        console.log(`  Script ${i+1}:`, script.src);
        console.log('  Script loaded:', script.readyState);
    });
}

// 4. Check if spreadsheet instance exists
console.log('\n4. Spreadsheet Instance:');
if (typeof spreadsheet !== 'undefined') {
    console.log('✅ Spreadsheet instance exists');
    console.log('typeof spreadsheet:', typeof spreadsheet);
    console.log('spreadsheet constructor:', spreadsheet.constructor.name);
} else {
    console.log('❌ Spreadsheet instance does NOT exist');
}

// 5. Check DOM elements
console.log('\n5. DOM Elements:');
const spreadsheetDiv = document.getElementById('spreadsheet');
console.log('Spreadsheet div exists:', !!spreadsheetDiv);
if (spreadsheetDiv) {
    console.log('Spreadsheet div innerHTML length:', spreadsheetDiv.innerHTML.length);
    console.log('Spreadsheet div children:', spreadsheetDiv.children.length);
    console.log('Spreadsheet div classes:', spreadsheetDiv.className);
}

// 6. Manual initialization test
console.log('\n6. Manual Initialization Test:');
function testManualInit() {
    console.log('Attempting manual initialization...');
    
    if (typeof ej === 'undefined') {
        console.log('❌ Cannot initialize - EJ2 not loaded');
        return false;
    }
    
    if (!ej.spreadsheet || !ej.spreadsheet.Spreadsheet) {
        console.log('❌ Cannot initialize - Spreadsheet constructor not available');
        return false;
    }
    
    try {
        const testSpreadsheet = new ej.spreadsheet.Spreadsheet({
            height: '400px',
            width: '100%'
        });
        
        console.log('✅ Manual initialization successful');
        console.log('Test spreadsheet:', testSpreadsheet);
        
        // Try to append to DOM
        testSpreadsheet.appendTo('#spreadsheet');
        console.log('✅ Manual append to DOM successful');
        
        return true;
    } catch (error) {
        console.log('❌ Manual initialization failed:', error.message);
        console.error('Full error:', error);
        return false;
    }
}

// 7. Network diagnostics
console.log('\n7. Network Diagnostics:');
function checkNetworkResources() {
    const resources = performance.getEntriesByType('resource');
    const ej2Resources = resources.filter(r => r.name.includes('ej2') || r.name.includes('syncfusion'));
    
    console.log('EJ2/Syncfusion resources loaded:', ej2Resources.length);
    ej2Resources.forEach((resource, i) => {
        console.log(`  Resource ${i+1}:`, resource.name);
        console.log(`    Status: ${resource.responseEnd > 0 ? 'Loaded' : 'Loading/Failed'}`);
        console.log(`    Duration: ${resource.duration}ms`);
        console.log(`    Size: ${resource.transferSize} bytes`);
    });
}

// Run diagnostics
console.log('\n🚀 Running Full Diagnostic...');
checkNetworkResources();

console.log('\n📋 Quick Commands:');
console.log('Run testManualInit() to test manual initialization');
console.log('Run checkLibraryStatus() if available in page');
console.log('Run forceInit() if available in page');

console.log('\n✅ Diagnostic Complete - Check results above');