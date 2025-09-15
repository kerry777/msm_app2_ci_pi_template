# EJ2 Spreadsheet Testing Guide

## Overview
This guide provides comprehensive testing instructions for the EJ2 Spreadsheet functionality in the Flutter MSM app.

## Current Status
✅ **Implementation Complete**: All components are in place  
✅ **Templates Available**: 6 Excel templates are present in assets/  
✅ **Debug Tools Added**: Debug screen and test HTML created  
✅ **Main Fixes Applied**: Asset paths and CDN versions corrected  

## Testing Steps

### 1. Navigate to EJ2 Spreadsheet
1. Launch the Flutter app in Chrome
2. Navigate to: **납품관리 (Delivery Management) > EJ2 Spreadsheet**
3. The screen should load with toolbar and empty spreadsheet

### 2. Test Debug Version (Recommended First)
1. Navigate to: **납품관리 (Delivery Management) > EJ2 Spreadsheet Debug**
2. This version provides detailed logging and diagnostic information
3. Check the debug panel on the right side for real-time logs

### 3. Test Template Loading
Try loading each template in order:

**Templates Available:**
- `MEK_SALES_TEMPLATE_PI.xlsx` - Proforma Invoice Template
- `MEK_SALES_TEMPLATE_CI.xlsx` - Commercial Invoice Template  
- `MEK_SALES_TEMPLATE_PL.xlsx` - Packing List Template
- `MEK_SALES_TEMPLATE_QT_EN.xlsx` - English Quotation Template
- `MEK_SALES_TEMPLATE_QT_KR.xlsx` - Korean Quotation Template
- `MEK_SALES_TEMPLATE_QT_AS.xlsx` - Asian Quotation Template

**Loading Process:**
1. Select template from dropdown
2. Click "Load Template" button
3. Watch status messages and debug logs
4. Verify template content loads in spreadsheet

### 4. Test Core Functions
After loading a template, test:

**Basic Operations:**
- ✅ Cell editing (click cell, type content)
- ✅ Cell formatting (bold, italic, colors)
- ✅ Row/column insertion and deletion
- ✅ Copy/paste operations

**Advanced Features:**
- ✅ Save document (downloads .xlsx file)
- ✅ Export to Excel (custom filename)
- ✅ Create new document (clears current content)
- ✅ Formula calculations

### 5. Browser Console Monitoring
1. Open Chrome Developer Tools (F12)
2. Go to Console tab
3. Look for these key messages:

**Success Messages:**
```
✅ EJ2 library loaded
✅ EJ2 Spreadsheet module available  
✅ EJ2 Spreadsheet initialized
✅ Template loaded successfully
```

**Error Messages to Watch For:**
```
❌ EJ2 library not loaded
❌ EJ2 Spreadsheet module not available
❌ Template not found
❌ Error initializing spreadsheet
```

## Standalone Testing
For isolated testing, open in browser:
```
http://localhost:<flutter-port>/ej2_test.html
```

This standalone test page provides:
- Library status checking
- Asset accessibility testing
- Direct EJ2 API testing
- Detailed error logging

## Common Issues & Solutions

### Issue 1: EJ2 Library Not Loading
**Symptoms:** Blank spreadsheet area, console shows "EJ2 library not loaded"  
**Solutions:**
- Check internet connection (CDN access required)
- Verify CDN URLs are accessible
- Try refreshing the page

### Issue 2: Templates Not Loading
**Symptoms:** "Template not found" errors, default template created instead  
**Solutions:**
- Verify assets are built correctly: `flutter build web`
- Check file paths in browser network tab
- Ensure templates exist in `build/web/assets/assets/`

### Issue 3: Spreadsheet Not Initializing
**Symptoms:** Loading spinner continues indefinitely  
**Solutions:**
- Check browser console for JavaScript errors
- Verify EJ2 version compatibility
- Clear browser cache and reload

### Issue 4: Template Content Not Displaying
**Symptoms:** Template loads but appears empty  
**Solutions:**
- Check Excel file format (should be .xlsx)
- Verify file is not corrupted
- Try different template files

## Debug Features

### Debug Screen Features
1. **Real-time Logging**: All JavaScript operations logged
2. **Asset Testing**: Test all template file accessibility
3. **Library Status**: Check EJ2 library loading status
4. **Error Capture**: JavaScript errors captured and displayed

### Debug Panel Controls
- **Test Assets**: Checks if all template files are accessible
- **Check Status**: Verifies EJ2 library and spreadsheet status
- **Toggle Debug Panel**: Show/hide debug information
- **Clear Log**: Reset debug log

## Performance Monitoring

### Expected Load Times
- **Initial Load**: 2-3 seconds (CDN loading)
- **Template Load**: 1-2 seconds (depending on file size)
- **Save/Export**: 1-2 seconds

### Memory Usage
- **Normal Operation**: ~50-100MB
- **With Large Templates**: ~100-200MB
- **Memory Leaks**: Watch for continuously increasing memory

## Error Reporting

When reporting issues, include:

1. **Browser Information**: Chrome version, operating system
2. **Console Logs**: Full JavaScript console output
3. **Network Tab**: Failed requests and response codes
4. **Debug Logs**: From debug screen if available
5. **Steps to Reproduce**: Exact sequence of actions
6. **Template File**: Which template was being loaded

## Advanced Diagnostics

### JavaScript Console Commands
Run in browser console for additional testing:

```javascript
// Check EJ2 availability
console.log('EJ2 available:', typeof ej !== 'undefined');
console.log('Spreadsheet module:', ej?.spreadsheet?.Spreadsheet !== undefined);

// Check spreadsheet instance
console.log('Spreadsheet instance:', window.spreadsheet);
console.log('Spreadsheet methods:', Object.keys(window.spreadsheet || {}));

// Test asset access
fetch('assets/MEK_SALES_TEMPLATE_PI.xlsx')
  .then(r => console.log('Asset status:', r.status))
  .catch(e => console.log('Asset error:', e));
```

### Network Monitoring
Monitor these requests in Network tab:
- `ej2.min.js` - Main EJ2 library
- `material.css` - EJ2 styling
- `MEK_SALES_TEMPLATE_*.xlsx` - Template files

## Success Criteria

The EJ2 Spreadsheet is working correctly when:

✅ Spreadsheet loads within 5 seconds  
✅ All 6 templates load successfully  
✅ Template content displays properly  
✅ Basic editing functions work  
✅ Save/Export functions work  
✅ No JavaScript errors in console  
✅ Memory usage remains stable  

## Next Steps After Testing

1. **Report Results**: Document any issues found
2. **Performance Tuning**: Optimize slow operations
3. **User Training**: Create user documentation
4. **Production Testing**: Test with real user data
5. **Mobile Testing**: Verify mobile browser compatibility

---

**Created:** $(date)  
**Version:** 1.0  
**Status:** Ready for Testing