
class Translations {
  static String get(String key, String language) {
    // AppLocalizations를 사용하도록 변경
    // 실제 사용시에는 context가 필요하므로 이 메서드는 더 이상 사용하지 않음
    // 대신 AppLocalizations.of(context).get(key) 사용 권장
    return key;
  }

  // 하위 호환성을 위한 메서드들
  static String getLogin(String language) => 'login';
  static String getId(String language) => 'id';
  static String getPassword(String language) => 'password';
  static String getLogout(String language) => 'logout';
  static String getHelp(String language) => 'help';
  static String getNotice(String language) => 'notice';
  static String getConfirm(String language) => 'confirm';
  static String getCancel(String language) => 'cancel';
  static String getSave(String language) => 'save';
  static String getEdit(String language) => 'edit';
  static String getClose(String language) => 'close';
  static String getSearch(String language) => 'search';
  static String getAvailable(String language) => 'available';
  static String getNextVersion(String language) => 'next_version';
  static String getStockCloseConfirmButton(String language) => 'stock_close_confirm_button';
  static String getStockStatus(String language) => 'stock_status';
  static String getStockManage(String language) => 'stock_manage';
  static String getStockClose(String language) => 'stock_close';
  static String getHelpUsage(String language) => 'help_usage';
  static String getHelpContact(String language) => 'help_contact';
  static String getCharts(String language) => 'charts';
  static String getStockSettings(String language) => 'stock_settings';
  static String getHospitalDelivery(String language) => 'hospital_delivery';
  static String getStockStatusAgent(String language) => 'stock_status_agent';
  static String getHospitalDeliveryManage(String language) => 'hospital_delivery_manage';
  static String getDashboard(String language) => 'dashboard';
  static String getItemExport(String language) => 'item_export';
  static String getItemReturn(String language) => 'item_return';
  static String getProductDelivery(String language) => 'product_delivery';
  static String getEtc(String language) => 'etc';
  static String getLoad(String language) => 'load';
  static String getFavoritesOnly(String language) => 'favorites_only';
  static String getSelect(String language) => 'select';
  static String getError(String language) => 'error';
  static String getItemRemark(String language) => 'item_remark';
  static String getOverwrite(String language) => 'overwrite';
  static String getReset(String language) => 'reset';
  static String getInputOnly(String language) => 'input_only';
  static String getNotInputOnly(String language) => 'not_input_only';
  static String getBulkApply(String language) => 'bulk_apply';
  static String getPreparing(String language) => 'preparing';
  static String getByHospital(String language) => 'by_hospital';
  static String getByItemGroup(String language) => 'by_item_group';
  static String getByItemSize(String language) => 'by_item_size';
  static String getByRegion(String language) => 'by_region';
  static String getByHospitalType(String language) => 'by_hospital_type';
  static String getByScale(String language) => 'by_scale';
  static String getDate(String language) => 'date';
  static String getHospitalName(String language) => 'hospital_name';
  static String getSalesAmount(String language) => 'sales_amount';
  static String getQuantity(String language) => 'quantity';
  static String getItemName(String language) => 'item_name';
  static String getItemCode(String language) => 'item_code';
  static String getCloseQuantity(String language) => 'close_quantity';
  static String getSafetyStock(String language) => 'safety_stock';
  static String getRemark(String language) => 'remark';
} 