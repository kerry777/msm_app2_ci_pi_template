class CustomerAnalyticsData {
  final String customerId;
  final String customerName;
  final String customerType; // '대형병원', '중형병원', '소형병원'
  final double totalSales;
  final int orderCount;
  final double averageOrderValue;
  final List<ProductSalesData> topProducts;
  final List<MonthlySalesData> monthlyTrend;

  CustomerAnalyticsData({
    required this.customerId,
    required this.customerName,
    required this.customerType,
    required this.totalSales,
    required this.orderCount,
    required this.averageOrderValue,
    required this.topProducts,
    required this.monthlyTrend,
  });

  factory CustomerAnalyticsData.fromJson(Map<String, dynamic> json) {
    return CustomerAnalyticsData(
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerType: json['customerType'] ?? '',
      totalSales: (json['totalSales'] ?? 0).toDouble(),
      orderCount: json['orderCount'] ?? 0,
      averageOrderValue: (json['averageOrderValue'] ?? 0).toDouble(),
      topProducts: (json['topProducts'] as List<dynamic>? ?? [])
          .map((item) => ProductSalesData.fromJson(item))
          .toList(),
      monthlyTrend: (json['monthlyTrend'] as List<dynamic>? ?? [])
          .map((item) => MonthlySalesData.fromJson(item))
          .toList(),
    );
  }
}

class ProductSalesData {
  final String productId;
  final String productName;
  final String category;
  final double totalSales;
  final int quantity;
  final List<CustomerSalesData> topCustomers;

  ProductSalesData({
    required this.productId,
    required this.productName,
    required this.category,
    required this.totalSales,
    required this.quantity,
    required this.topCustomers,
  });

  factory ProductSalesData.fromJson(Map<String, dynamic> json) {
    return ProductSalesData(
      productId: json['productId'] ?? '',
      productName: json['productName'] ?? '',
      category: json['category'] ?? '',
      totalSales: (json['totalSales'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
      topCustomers: (json['topCustomers'] as List<dynamic>? ?? [])
          .map((item) => CustomerSalesData.fromJson(item))
          .toList(),
    );
  }
}

class CustomerSalesData {
  final String customerId;
  final String customerName;
  final double salesAmount;
  final int quantity;

  CustomerSalesData({
    required this.customerId,
    required this.customerName,
    required this.salesAmount,
    required this.quantity,
  });

  factory CustomerSalesData.fromJson(Map<String, dynamic> json) {
    return CustomerSalesData(
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      salesAmount: (json['salesAmount'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 0,
    );
  }
}

class MonthlySalesData {
  final String month;
  final double sales;
  final int orderCount;

  MonthlySalesData({
    required this.month,
    required this.sales,
    required this.orderCount,
  });

  factory MonthlySalesData.fromJson(Map<String, dynamic> json) {
    return MonthlySalesData(
      month: json['month'] ?? '',
      sales: (json['sales'] ?? 0).toDouble(),
      orderCount: json['orderCount'] ?? 0,
    );
  }
}

// 드릴다운 데이터 모델
enum DrillDownLevel {
  region,    // 지역 (서울, 부산, 대구 등)
  hospital,  // 병원 (서울대병원, 삼성서울병원 등)
  product,   // 상품 (의료기기 A, 치료용품 B 등)
}

class DrillDownData {
  final String id;
  final String name;
  final double value;
  final DrillDownLevel level;
  final String? parentId; // 상위 레벨의 ID
  final List<DrillDownData>? children; // 하위 레벨 데이터

  DrillDownData({
    required this.id,
    required this.name,
    required this.value,
    required this.level,
    this.parentId,
    this.children,
  });

  factory DrillDownData.fromJson(Map<String, dynamic> json) {
    return DrillDownData(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      value: (json['value'] ?? 0).toDouble(),
      level: DrillDownLevel.values[json['level'] ?? 0],
      parentId: json['parentId'],
      children: (json['children'] as List<dynamic>?)
          ?.map((item) => DrillDownData.fromJson(item))
          .toList(),
    );
  }
}

class DrillDownState {
  final DrillDownLevel currentLevel;
  final List<DrillDownData> currentData;
  final List<String> breadcrumbPath;
  final String? selectedItemId;

  DrillDownState({
    required this.currentLevel,
    required this.currentData,
    required this.breadcrumbPath,
    this.selectedItemId,
  });

  DrillDownState copyWith({
    DrillDownLevel? currentLevel,
    List<DrillDownData>? currentData,
    List<String>? breadcrumbPath,
    String? selectedItemId,
  }) {
    return DrillDownState(
      currentLevel: currentLevel ?? this.currentLevel,
      currentData: currentData ?? this.currentData,
      breadcrumbPath: breadcrumbPath ?? this.breadcrumbPath,
      selectedItemId: selectedItemId ?? this.selectedItemId,
    );
  }
}

// Mock 데이터 생성기
class AnalyticsMockData {
  static List<CustomerAnalyticsData> getCustomerAnalyticsData() {
    return [
      CustomerAnalyticsData(
        customerId: 'CUST001',
        customerName: '서울대병원',
        customerType: '대형병원',
        totalSales: 125000000,
        orderCount: 45,
        averageOrderValue: 2777778,
        topProducts: [
          ProductSalesData(
            productId: 'PROD001',
            productName: '의료기기 A',
            category: '진단장비',
            totalSales: 35000000,
            quantity: 14,
            topCustomers: [],
          ),
          ProductSalesData(
            productId: 'PROD002',
            productName: '치료용품 B',
            category: '치료장비',
            totalSales: 28000000,
            quantity: 23,
            topCustomers: [],
          ),
        ],
        monthlyTrend: [
          MonthlySalesData(month: '2024-01', sales: 15000000, orderCount: 5),
          MonthlySalesData(month: '2024-02', sales: 18000000, orderCount: 6),
          MonthlySalesData(month: '2024-03', sales: 22000000, orderCount: 8),
        ],
      ),
      CustomerAnalyticsData(
        customerId: 'CUST002',
        customerName: '삼성서울병원',
        customerType: '대형병원',
        totalSales: 87500000,
        orderCount: 32,
        averageOrderValue: 2734375,
        topProducts: [
          ProductSalesData(
            productId: 'PROD003',
            productName: '진단장비 C',
            category: '진단장비',
            totalSales: 24000000,
            quantity: 8,
            topCustomers: [],
          ),
        ],
        monthlyTrend: [
          MonthlySalesData(month: '2024-01', sales: 12000000, orderCount: 4),
          MonthlySalesData(month: '2024-02', sales: 16000000, orderCount: 6),
          MonthlySalesData(month: '2024-03', sales: 19000000, orderCount: 7),
        ],
      ),
    ];
  }

  static List<ProductSalesData> getProductAnalyticsData() {
    return [
      ProductSalesData(
        productId: 'PROD001',
        productName: '의료기기 A',
        category: '진단장비',
        totalSales: 85000000,
        quantity: 42,
        topCustomers: [
          CustomerSalesData(
            customerId: 'CUST001',
            customerName: '서울대병원',
            salesAmount: 35000000,
            quantity: 14,
          ),
          CustomerSalesData(
            customerId: 'CUST003',
            customerName: '연세병원',
            salesAmount: 28000000,
            quantity: 12,
          ),
        ],
      ),
      ProductSalesData(
        productId: 'PROD002',
        productName: '치료용품 B',
        category: '치료장비',
        totalSales: 67000000,
        quantity: 78,
        topCustomers: [
          CustomerSalesData(
            customerId: 'CUST001',
            customerName: '서울대병원',
            salesAmount: 28000000,
            quantity: 23,
          ),
          CustomerSalesData(
            customerId: 'CUST002',
            customerName: '삼성서울병원',
            salesAmount: 22000000,
            quantity: 18,
          ),
        ],
      ),
    ];
  }
}