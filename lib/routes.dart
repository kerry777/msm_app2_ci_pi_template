import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

// 병원재고조사 관련 import 제거됨
import 'screens/agency_stock_status_screen.dart';
import 'screens/agency_stock_analytics_screen.dart';
import 'screens/agent_stock_status_screen.dart';
import 'screens/item_export_screen.dart';
import 'screens/item_return_screen.dart';
import 'screens/stock_close_regist_screen.dart';
import 'screens/stock_close_history_screen.dart';
import 'screens/auto_order_history_screen.dart';
import 'screens/stock_close_analytics_screen.dart';
import 'screens/agency_sales_screen.dart';
import 'screens/hospital_master_screen.dart';
import 'screens/stock_close_raw_screen.dart';
import 'screens/agency_sales_chart_screen.dart';
import 'screens/ej2_spreadsheet_simple_screen.dart';
import 'screens/analytics_spa_screen.dart';
import 'screens/advanced_pivot_table_screen.dart';

class Routes {
  static const String login = '/login';
  static const String main = '/main';

  // 병원재고조사 라우트 제거됨

  static const String agencyStockStatus = '/agency-stock-status';
  static const String agencyStockAnalytics = '/agency-stock-analytics';
  static const String agentStockStatus = '/agent-stock-status';
  static const String itemExport = '/item-export';
  static const String itemReturn = '/item-return';
  static const String stockCloseRegist = '/stock-close-regist';
  static const String stockCloseHistory = '/stock-close-history';
  static const String autoOrderHistory = '/auto-order-history';
  static const String stockCloseAnalytics = '/stock-close-analytics';
  static const String stockCloseRaw = '/stock-close-raw';
  static const String agencySales = '/agency-sales';
  static const String hospitalMaster = '/hospital-master';
  static const String ej2SpreadsheetSimple = '/ej2-spreadsheet-simple';
  static const String analyticsSpa = '/analytics-spa';
  static const String hospitalSales = '/hospital-sales';
  static const String advancedPivotTable = '/advanced-pivot-table';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      main: (context) => const MainScreen(),

      // 병원재고조사 라우트 제거됨

      agencyStockStatus: (context) => const AgencyStockStatusScreen(),
      agencyStockAnalytics: (context) => const AgencyStockAnalyticsScreen(),
      agentStockStatus: (context) => const AgentStockStatusScreen(),
      itemExport: (context) => const ItemExportScreen(),
      itemReturn: (context) => const ItemReturnScreen(),
      stockCloseRegist: (context) => const StockCloseRegistScreen(),
      stockCloseHistory: (context) => const StockCloseHistoryScreen(),
      autoOrderHistory: (context) => const AutoOrderHistoryScreen(),
      stockCloseAnalytics: (context) => const StockCloseAnalyticsScreen(),
      stockCloseRaw: (context) => const StockCloseRawScreen(data: []),
      agencySales: (context) => const AgencySalesScreen(),
      hospitalMaster: (context) => const HospitalMasterScreen(),
      ej2SpreadsheetSimple: (context) => const EJ2SpreadsheetSimpleScreen(),
      analyticsSpa: (context) => const AnalyticsSpaScreen(),
      hospitalSales: (context) => const AgencySalesScreen(),
      advancedPivotTable: (context) => const AdvancedPivotTableScreen(),
      'salesChart': (context) => const AgencySalesChartScreen(),
    };
  }
} 