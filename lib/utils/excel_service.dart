// 플랫폼별 분기 import
export 'excel_service_stub.dart'
    if (dart.library.html) 'excel_service_web.dart'
    if (dart.library.io) 'excel_service_io.dart'; 