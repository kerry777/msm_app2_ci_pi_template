import 'package:flutter/material.dart';

class ResponsiveHelper {
  // 브레이크포인트 정의
  static const double mobileBreakpoint = 600;      // 모바일
  static const double tabletBreakpoint = 1024;     // 태블릿
  static const double desktopBreakpoint = 1440;    // 데스크탑
  static const double largeDesktopBreakpoint = 1920; // 대형 데스크탑

  // 현재 화면 타입 결정
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < mobileBreakpoint) {
      return ScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return ScreenType.tablet;
    } else if (width < desktopBreakpoint) {
      return ScreenType.desktop;
    } else {
      return ScreenType.largeDesktop;
    }
  }

  // 화면 크기별 여백 계산
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return EdgeInsets.all(mobile ?? 16);
      case ScreenType.tablet:
        return EdgeInsets.all(tablet ?? 24);
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return EdgeInsets.all(desktop ?? 32);
    }
  }

  // 화면 크기별 마진 계산
  static EdgeInsets getResponsiveMargin(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return EdgeInsets.all(mobile ?? 8);
      case ScreenType.tablet:
        return EdgeInsets.all(tablet ?? 16);
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return EdgeInsets.all(desktop ?? 24);
    }
  }

  // 화면 크기별 폰트 크기 계산
  static double getResponsiveFontSize(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return mobile ?? 14;
      case ScreenType.tablet:
        return tablet ?? 16;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return desktop ?? 18;
    }
  }

  // 화면 크기별 컬럼 수 계산
  static int getResponsiveColumns(BuildContext context, {
    int? mobile,
    int? tablet,
    int? desktop,
  }) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return mobile ?? 1;
      case ScreenType.tablet:
        return tablet ?? 2;
      case ScreenType.desktop:
        return desktop ?? 3;
      case ScreenType.largeDesktop:
        return desktop ?? 4;
    }
  }

  // 화면 크기별 그리드 크기 계산
  static double getResponsiveGridItemSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return (width - 48) / 1; // 1열, 양쪽 여백 24씩
      case ScreenType.tablet:
        return (width - 72) / 2; // 2열, 양쪽 여백 24, 중간 간격 24
      case ScreenType.desktop:
        return (width - 128) / 3; // 3열
      case ScreenType.largeDesktop:
        return (width - 160) / 4; // 4열
    }
  }

  // 화면 크기별 차트 높이 계산
  static double getResponsiveChartHeight(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return height * 0.3; // 화면 높이의 30%
      case ScreenType.tablet:
        return height * 0.4; // 화면 높이의 40%
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return height * 0.5; // 화면 높이의 50%
    }
  }

  // 모바일 여부 확인
  static bool isMobile(BuildContext context) {
    return getScreenType(context) == ScreenType.mobile;
  }

  // 태블릿 여부 확인
  static bool isTablet(BuildContext context) {
    return getScreenType(context) == ScreenType.tablet;
  }

  // 데스크탑 여부 확인
  static bool isDesktop(BuildContext context) {
    final screenType = getScreenType(context);
    return screenType == ScreenType.desktop || screenType == ScreenType.largeDesktop;
  }

  // 세로 모드 여부 확인
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  // 가로 모드 여부 확인
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // 화면 크기별 앱바 높이 계산
  static double getResponsiveAppBarHeight(BuildContext context) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return 56;
      case ScreenType.tablet:
        return 64;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return 72;
    }
  }

  // 화면 크기별 아이콘 크기 계산
  static double getResponsiveIconSize(BuildContext context, {
    double? mobile,
    double? tablet,
    double? desktop,
  }) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return mobile ?? 24;
      case ScreenType.tablet:
        return tablet ?? 28;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return desktop ?? 32;
    }
  }

  // 화면 크기별 버튼 높이 계산
  static double getResponsiveButtonHeight(BuildContext context) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return 48;
      case ScreenType.tablet:
        return 52;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return 56;
    }
  }

  // 화면 크기별 카드 elevation 계산
  static double getResponsiveElevation(BuildContext context) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return 2;
      case ScreenType.tablet:
        return 4;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return 8;
    }
  }

  // 최대 콘텐츠 폭 계산 (가독성을 위한 제한)
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return width;
      case ScreenType.tablet:
        return width;
      case ScreenType.desktop:
        return 1200; // 데스크탑에서는 최대 폭 제한
      case ScreenType.largeDesktop:
        return 1400;
    }
  }

  // 화면 크기별 사이드바 폭 계산
  static double getResponsiveSidebarWidth(BuildContext context) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return 280; // 모바일에서는 drawer 형태
      case ScreenType.tablet:
        return 300;
      case ScreenType.desktop:
        return 320;
      case ScreenType.largeDesktop:
        return 360;
    }
  }

  // 화면 크기별 데이터 테이블 행 높이
  static double getResponsiveTableRowHeight(BuildContext context) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return 56;
      case ScreenType.tablet:
        return 60;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return 64;
    }
  }

  // 반응형 그리드 설정 계산
  static ResponsiveGridSettings getResponsiveGridSettings(BuildContext context) {
    final screenType = getScreenType(context);
    final width = MediaQuery.of(context).size.width;

    switch (screenType) {
      case ScreenType.mobile:
        return ResponsiveGridSettings(
          crossAxisCount: 1,
          childAspectRatio: 1.2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          maxItemWidth: width - 32,
        );

      case ScreenType.tablet:
        return ResponsiveGridSettings(
          crossAxisCount: 2,
          childAspectRatio: 1.1,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          maxItemWidth: (width - 64) / 2,
        );

      case ScreenType.desktop:
        return ResponsiveGridSettings(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          maxItemWidth: (width - 96) / 3,
        );

      case ScreenType.largeDesktop:
        return ResponsiveGridSettings(
          crossAxisCount: 4,
          childAspectRatio: 0.9,
          crossAxisSpacing: 28,
          mainAxisSpacing: 28,
          maxItemWidth: (width - 140) / 4,
        );
    }
  }

  // 화면 비율별 차트 설정 계산
  static ResponsiveChartSettings getResponsiveChartSettings(BuildContext context) {
    final screenType = getScreenType(context);
    final size = MediaQuery.of(context).size;

    return ResponsiveChartSettings(
      height: getResponsiveChartHeight(context),
      titleFontSize: getResponsiveFontSize(context,
        mobile: 16, tablet: 18, desktop: 20),
      labelFontSize: getResponsiveFontSize(context,
        mobile: 12, tablet: 14, desktop: 16),
      legendFontSize: getResponsiveFontSize(context,
        mobile: 10, tablet: 12, desktop: 14),
      showLegend: screenType != ScreenType.mobile,
      showDataLabels: screenType == ScreenType.desktop || screenType == ScreenType.largeDesktop,
      animationDuration: screenType == ScreenType.mobile ? 500 : 1000,
    );
  }

  // 반응형 레이아웃 방향 결정
  static Axis getResponsiveLayoutDirection(BuildContext context, {
    Axis? mobile,
    Axis? tablet,
    Axis? desktop,
  }) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return mobile ?? Axis.vertical;
      case ScreenType.tablet:
        return tablet ?? Axis.horizontal;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return desktop ?? Axis.horizontal;
    }
  }

  // 반응형 모달 크기 계산
  static ResponsiveModalSettings getResponsiveModalSettings(BuildContext context) {
    final screenType = getScreenType(context);
    final size = MediaQuery.of(context).size;

    switch (screenType) {
      case ScreenType.mobile:
        return ResponsiveModalSettings(
          width: size.width * 0.95,
          maxHeight: size.height * 0.9,
          padding: const EdgeInsets.all(16),
          borderRadius: 16,
        );

      case ScreenType.tablet:
        return ResponsiveModalSettings(
          width: size.width * 0.8,
          maxHeight: size.height * 0.8,
          padding: const EdgeInsets.all(24),
          borderRadius: 20,
        );

      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return ResponsiveModalSettings(
          width: 600,
          maxHeight: size.height * 0.7,
          padding: const EdgeInsets.all(32),
          borderRadius: 24,
        );
    }
  }

  // 반응형 텍스트 스케일 계산
  static double getResponsiveTextScale(BuildContext context) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return 1.0;
      case ScreenType.tablet:
        return 1.1;
      case ScreenType.desktop:
        return 1.2;
      case ScreenType.largeDesktop:
        return 1.3;
    }
  }

  // SafeArea 여백을 고려한 실제 사용 가능한 크기 계산
  static Size getUsableSize(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Size(
      size.width,
      size.height - padding.top - padding.bottom,
    );
  }

  // 키보드 표시 상태를 고려한 사용 가능한 높이 계산
  static double getAvailableHeight(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return size.height - padding.top - padding.bottom - viewInsets.bottom;
  }
}

// 화면 타입
enum ScreenType {
  mobile,
  tablet,
  desktop,
  largeDesktop,
}

// 반응형 그리드 설정
class ResponsiveGridSettings {
  final int crossAxisCount;
  final double childAspectRatio;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double maxItemWidth;

  const ResponsiveGridSettings({
    required this.crossAxisCount,
    required this.childAspectRatio,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.maxItemWidth,
  });
}

// 반응형 차트 설정
class ResponsiveChartSettings {
  final double height;
  final double titleFontSize;
  final double labelFontSize;
  final double legendFontSize;
  final bool showLegend;
  final bool showDataLabels;
  final int animationDuration;

  const ResponsiveChartSettings({
    required this.height,
    required this.titleFontSize,
    required this.labelFontSize,
    required this.legendFontSize,
    required this.showLegend,
    required this.showDataLabels,
    required this.animationDuration,
  });
}

// 반응형 모달 설정
class ResponsiveModalSettings {
  final double width;
  final double maxHeight;
  final EdgeInsets padding;
  final double borderRadius;

  const ResponsiveModalSettings({
    required this.width,
    required this.maxHeight,
    required this.padding,
    required this.borderRadius,
  });
}

// 반응형 위젯 빌더
class ResponsiveBuilder extends StatelessWidget {
  final Widget? mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? largeDesktop;
  final Widget Function(BuildContext, ScreenType)? builder;

  const ResponsiveBuilder({
    Key? key,
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
    this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenType = ResponsiveHelper.getScreenType(context);

    if (builder != null) {
      return builder!(context, screenType);
    }

    switch (screenType) {
      case ScreenType.mobile:
        return mobile ?? tablet ?? desktop ?? largeDesktop ?? Container();
      case ScreenType.tablet:
        return tablet ?? mobile ?? desktop ?? largeDesktop ?? Container();
      case ScreenType.desktop:
        return desktop ?? largeDesktop ?? tablet ?? mobile ?? Container();
      case ScreenType.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile ?? Container();
    }
  }
}

// 반응형 값 선택기
class ResponsiveValue<T> {
  final T? mobile;
  final T? tablet;
  final T? desktop;
  final T? largeDesktop;

  const ResponsiveValue({
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  T getValue(BuildContext context) {
    final screenType = ResponsiveHelper.getScreenType(context);

    switch (screenType) {
      case ScreenType.mobile:
        return mobile ?? tablet ?? desktop ?? largeDesktop!;
      case ScreenType.tablet:
        return tablet ?? mobile ?? desktop ?? largeDesktop!;
      case ScreenType.desktop:
        return desktop ?? largeDesktop ?? tablet ?? mobile!;
      case ScreenType.largeDesktop:
        return largeDesktop ?? desktop ?? tablet ?? mobile!;
    }
  }
}

// 반응형 패딩 위젯
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsets? mobile;
  final EdgeInsets? tablet;
  final EdgeInsets? desktop;
  final EdgeInsets? largeDesktop;

  const ResponsivePadding({
    Key? key,
    required this.child,
    this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveValue<EdgeInsets>(
      mobile: mobile,
      tablet: tablet,
      desktop: desktop,
      largeDesktop: largeDesktop,
    ).getValue(context);

    return Padding(
      padding: padding,
      child: child,
    );
  }
}

// 반응형 중앙 정렬 위젯
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveCenter({
    Key? key,
    required this.child,
    this.maxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxContentWidth = maxWidth ?? ResponsiveHelper.getMaxContentWidth(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: child,
      ),
    );
  }
}