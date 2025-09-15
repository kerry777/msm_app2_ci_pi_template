import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'dart:math' as math;

/// 고급 차트 애니메이션 및 트랜지션 시스템
/// - 부드러운 데이터 전환 애니메이션
/// - 인터랙티브 애니메이션
/// - 물리 기반 애니메이션
/// - 파티클 효과
/// - 모프 트랜지션
class ChartAnimations extends StatefulWidget {
  final Widget child;
  final AnimationType animationType;
  final Duration duration;
  final Curve curve;
  final VoidCallback? onAnimationComplete;
  final bool enableParticleEffect;
  final bool enableMorphTransition;

  const ChartAnimations({
    super.key,
    required this.child,
    this.animationType = AnimationType.slideUp,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOutCubic,
    this.onAnimationComplete,
    this.enableParticleEffect = false,
    this.enableMorphTransition = false,
  });

  @override
  State<ChartAnimations> createState() => _ChartAnimationsState();
}

class _ChartAnimationsState extends State<ChartAnimations>
    with TickerProviderStateMixin {

  late AnimationController _primaryController;
  late AnimationController _particleController;
  late AnimationController _morphController;

  // 기본 애니메이션들
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  // 고급 애니메이션들
  late Animation<double> _particleAnimation;
  late Animation<double> _morphAnimation;

  // 물리 기반 애니메이션
  late AnimationController _physicsController;
  late Animation<double> _physicsAnimation;

  // 파티클 시스템
  final List<Particle> _particles = [];
  final int _particleCount = 50;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimation();
  }

  void _initializeAnimations() {
    // 메인 애니메이션 컨트롤러
    _primaryController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    // 파티클 애니메이션 컨트롤러
    _particleController = AnimationController(
      duration: Duration(milliseconds: widget.duration.inMilliseconds + 500),
      vsync: this,
    );

    // 모프 애니메이션 컨트롤러
    _morphController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 물리 기반 애니메이션 컨트롤러
    _physicsController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // 기본 애니메이션들 설정
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: Interval(0.0, 0.8, curve: widget.curve),
    ));

    _slideAnimation = Tween<Offset>(
      begin: _getSlideBeginOffset(),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: widget.curve,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: Curves.elasticOut,
    ));

    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: Curves.easeOutBack,
    ));

    // 파티클 애니메이션
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    ));

    // 모프 애니메이션
    _morphAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _morphController,
      curve: Curves.elasticInOut,
    ));

    // 물리 기반 애니메이션
    _setupPhysicsAnimation();

    // 파티클 초기화
    if (widget.enableParticleEffect) {
      _initializeParticles();
    }

    // 애니메이션 완료 콜백
    _primaryController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  void _setupPhysicsAnimation() {
    final spring = SpringDescription(
      mass: 1.0,
      stiffness: 500.0,
      damping: 15.0,
    );

    final simulation = SpringSimulation(
      spring,
      0.0,
      1.0,
      0.0,
    );

    _physicsAnimation = _physicsController.drive(
      Tween<double>(begin: 0.0, end: 1.0),
    );

    _physicsController.animateWith(simulation);
  }

  void _initializeParticles() {
    _particles.clear();
    final random = math.Random();

    for (int i = 0; i < _particleCount; i++) {
      _particles.add(Particle(
        position: Offset(
          random.nextDouble() * 400,
          random.nextDouble() * 600,
        ),
        velocity: Offset(
          (random.nextDouble() - 0.5) * 200,
          (random.nextDouble() - 0.5) * 200,
        ),
        color: _getRandomParticleColor(random),
        size: random.nextDouble() * 4 + 1,
        life: 1.0,
        lifespan: random.nextDouble() * 2 + 1,
      ));
    }
  }

  Color _getRandomParticleColor(math.Random random) {
    final colors = [
      Colors.blue.withOpacity(0.7),
      Colors.green.withOpacity(0.7),
      Colors.orange.withOpacity(0.7),
      Colors.purple.withOpacity(0.7),
      Colors.teal.withOpacity(0.7),
    ];
    return colors[random.nextInt(colors.length)];
  }

  Offset _getSlideBeginOffset() {
    switch (widget.animationType) {
      case AnimationType.slideUp:
        return const Offset(0.0, 1.0);
      case AnimationType.slideDown:
        return const Offset(0.0, -1.0);
      case AnimationType.slideLeft:
        return const Offset(1.0, 0.0);
      case AnimationType.slideRight:
        return const Offset(-1.0, 0.0);
      case AnimationType.slideUpLeft:
        return const Offset(1.0, 1.0);
      case AnimationType.slideUpRight:
        return const Offset(-1.0, 1.0);
      default:
        return const Offset(0.0, 1.0);
    }
  }

  void _startAnimation() {
    // 순차적 애니메이션 시작
    _primaryController.forward();

    if (widget.enableParticleEffect) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _particleController.forward();
      });
    }

    if (widget.enableMorphTransition) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _morphController.forward();
      });
    }
  }

  void _updateParticles() {
    final dt = 0.016; // 60 FPS
    final animationValue = _particleAnimation.value;

    for (final particle in _particles) {
      // 위치 업데이트
      particle.position += particle.velocity * dt;

      // 수명 감소
      particle.life -= dt / particle.lifespan;

      // 중력 효과
      particle.velocity += const Offset(0, 98) * dt;

      // 경계 반사
      if (particle.position.dx < 0 || particle.position.dx > 400) {
        particle.velocity = Offset(-particle.velocity.dx * 0.8, particle.velocity.dy);
      }
      if (particle.position.dy > 600) {
        particle.velocity = Offset(particle.velocity.dx, -particle.velocity.dy * 0.6);
        particle.position = Offset(particle.position.dx, 600);
      }

      // 투명도 조정
      particle.opacity = (particle.life * animationValue).clamp(0.0, 1.0);
    }

    // 죽은 파티클 제거
    _particles.removeWhere((particle) => particle.life <= 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _primaryController,
        _particleController,
        _morphController,
        _physicsController,
      ]),
      builder: (context, child) {
        if (widget.enableParticleEffect) {
          _updateParticles();
        }

        Widget animatedChild = widget.child;

        // 애니메이션 타입에 따라 다른 효과 적용
        switch (widget.animationType) {
          case AnimationType.fade:
            animatedChild = FadeTransition(
              opacity: _fadeAnimation,
              child: animatedChild,
            );
            break;

          case AnimationType.scale:
            animatedChild = ScaleTransition(
              scale: _scaleAnimation,
              child: animatedChild,
            );
            break;

          case AnimationType.rotate:
            animatedChild = RotationTransition(
              turns: _rotateAnimation,
              child: animatedChild,
            );
            break;

          case AnimationType.physics:
            animatedChild = Transform.scale(
              scale: _physicsAnimation.value,
              child: FadeTransition(
                opacity: _physicsAnimation,
                child: animatedChild,
              ),
            );
            break;

          case AnimationType.morph:
            if (widget.enableMorphTransition) {
              animatedChild = _buildMorphTransition(animatedChild);
            }
            break;

          case AnimationType.wave:
            animatedChild = _buildWaveTransition(animatedChild);
            break;

          case AnimationType.ripple:
            animatedChild = _buildRippleTransition(animatedChild);
            break;

          case AnimationType.elastic:
            animatedChild = Transform.scale(
              scale: Curves.elasticOut.transform(_primaryController.value),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: animatedChild,
              ),
            );
            break;

          case AnimationType.bounce:
            animatedChild = Transform.translate(
              offset: Offset(
                0,
                -50 * math.sin(_primaryController.value * math.pi) *
                    (1 - _primaryController.value),
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: animatedChild,
              ),
            );
            break;

          default:
            // 기본 슬라이드 애니메이션
            animatedChild = SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: animatedChild,
              ),
            );
            break;
        }

        // 파티클 효과 추가
        if (widget.enableParticleEffect) {
          animatedChild = Stack(
            children: [
              animatedChild,
              Positioned.fill(
                child: CustomPaint(
                  painter: ParticlePainter(_particles),
                ),
              ),
            ],
          );
        }

        return animatedChild;
      },
    );
  }

  Widget _buildMorphTransition(Widget child) {
    return AnimatedBuilder(
      animation: _morphAnimation,
      builder: (context, _) {
        return ClipPath(
          clipper: MorphClipper(_morphAnimation.value),
          child: child,
        );
      },
    );
  }

  Widget _buildWaveTransition(Widget child) {
    return AnimatedBuilder(
      animation: _primaryController,
      builder: (context, _) {
        return ClipPath(
          clipper: WaveClipper(_primaryController.value),
          child: child,
        );
      },
    );
  }

  Widget _buildRippleTransition(Widget child) {
    return AnimatedBuilder(
      animation: _primaryController,
      builder: (context, _) {
        return ClipOval(
          clipper: RippleClipper(_primaryController.value),
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _primaryController.dispose();
    _particleController.dispose();
    _morphController.dispose();
    _physicsController.dispose();
    super.dispose();
  }
}

/// 데이터 전환 애니메이션 위젯
class ChartDataTransition extends StatefulWidget {
  final Widget oldChild;
  final Widget newChild;
  final Duration duration;
  final TransitionType transitionType;

  const ChartDataTransition({
    super.key,
    required this.oldChild,
    required this.newChild,
    this.duration = const Duration(milliseconds: 600),
    this.transitionType = TransitionType.crossFade,
  });

  @override
  State<ChartDataTransition> createState() => _ChartDataTransitionState();
}

class _ChartDataTransitionState extends State<ChartDataTransition>
    with TickerProviderStateMixin {

  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showNewChild = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _startTransition();
  }

  void _startTransition() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _showNewChild = true;
      });
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.transitionType) {
      case TransitionType.crossFade:
        return AnimatedCrossFade(
          firstChild: widget.oldChild,
          secondChild: widget.newChild,
          crossFadeState: _showNewChild
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
          duration: widget.duration,
        );

      case TransitionType.slideReplace:
        return AnimatedSwitcher(
          duration: widget.duration,
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: _showNewChild ? widget.newChild : widget.oldChild,
        );

      case TransitionType.scaleReplace:
        return AnimatedSwitcher(
          duration: widget.duration,
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: animation,
              child: child,
            );
          },
          child: _showNewChild ? widget.newChild : widget.oldChild,
        );

      case TransitionType.fadeReplace:
        return AnimatedSwitcher(
          duration: widget.duration,
          child: _showNewChild ? widget.newChild : widget.oldChild,
        );

      case TransitionType.morphReplace:
        return AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            if (_animation.value < 0.5) {
              return Transform.scale(
                scale: 1.0 - (_animation.value * 2),
                child: widget.oldChild,
              );
            } else {
              return Transform.scale(
                scale: (_animation.value - 0.5) * 2,
                child: widget.newChild,
              );
            }
          },
        );

      default:
        return widget.newChild;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// 인터랙티브 차트 애니메이션 위젯
class InteractiveChartAnimation extends StatefulWidget {
  final Widget child;
  final Function(Offset)? onTap;
  final Function(Offset)? onHover;
  final bool enableHoverEffect;
  final bool enableRippleEffect;

  const InteractiveChartAnimation({
    super.key,
    required this.child,
    this.onTap,
    this.onHover,
    this.enableHoverEffect = true,
    this.enableRippleEffect = true,
  });

  @override
  State<InteractiveChartAnimation> createState() => _InteractiveChartAnimationState();
}

class _InteractiveChartAnimationState extends State<InteractiveChartAnimation>
    with TickerProviderStateMixin {

  late AnimationController _hoverController;
  late AnimationController _rippleController;

  late Animation<double> _hoverAnimation;
  late Animation<double> _rippleAnimation;

  bool _isHovered = false;
  Offset? _rippleCenter;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _hoverAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOut,
    ));
  }

  void _handleTap(TapDownDetails details) {
    if (widget.enableRippleEffect) {
      setState(() {
        _rippleCenter = details.localPosition;
      });

      _rippleController.reset();
      _rippleController.forward();
    }

    widget.onTap?.call(details.localPosition);
  }

  void _handleHover(PointerHoverEvent event) {
    if (!_isHovered && widget.enableHoverEffect) {
      setState(() {
        _isHovered = true;
      });
      _hoverController.forward();
    }

    widget.onHover?.call(event.localPosition);
  }

  void _handleExit(PointerExitEvent event) {
    if (_isHovered && widget.enableHoverEffect) {
      setState(() {
        _isHovered = false;
      });
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTap,
      child: MouseRegion(
        onHover: _handleHover,
        onExit: _handleExit,
        child: AnimatedBuilder(
          animation: Listenable.merge([_hoverController, _rippleController]),
          builder: (context, _) {
            Widget child = widget.child;

            // 호버 효과
            if (widget.enableHoverEffect) {
              child = Transform.scale(
                scale: _hoverAnimation.value,
                child: child,
              );
            }

            // 리플 효과
            if (widget.enableRippleEffect && _rippleCenter != null) {
              child = Stack(
                children: [
                  child,
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RipplePainter(
                        center: _rippleCenter!,
                        animation: _rippleAnimation,
                      ),
                    ),
                  ),
                ],
              );
            }

            return child;
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _rippleController.dispose();
    super.dispose();
  }
}

/// 파티클 클래스
class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double life;
  double lifespan;
  double opacity;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
    required this.lifespan,
    this.opacity = 1.0,
  });
}

/// 파티클 페인터
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      if (particle.opacity > 0) {
        final paint = Paint()
          ..color = particle.color.withOpacity(particle.opacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(
          particle.position,
          particle.size,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 리플 페인터
class RipplePainter extends CustomPainter {
  final Offset center;
  final Animation<double> animation;

  RipplePainter({
    required this.center,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (animation.value > 0) {
      final paint = Paint()
        ..color = Colors.blue.withOpacity(0.3 * (1 - animation.value))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final radius = animation.value * 100;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// 모프 클리퍼
class MorphClipper extends CustomClipper<Path> {
  final double progress;

  MorphClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();

    if (progress < 0.5) {
      // 원형에서 사각형으로
      final t = progress * 2;
      final radius = (size.width / 2) * (1 - t);
      final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * t + radius * 2 * (1 - t),
        height: size.height * t + radius * 2 * (1 - t),
      );

      if (t < 1) {
        path.addOval(rect);
      } else {
        path.addRect(rect);
      }
    } else {
      // 사각형 완성
      path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

/// 웨이브 클리퍼
class WaveClipper extends CustomClipper<Path> {
  final double progress;

  WaveClipper(this.progress);

  @override
  Path getClip(Size size) {
    final path = Path();
    final waveHeight = size.height * progress;

    path.moveTo(0, size.height - waveHeight);

    for (double x = 0; x <= size.width; x += 10) {
      final y = size.height - waveHeight +
          math.sin((x / size.width) * 2 * math.pi + progress * 2 * math.pi) * 20;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

/// 리플 클리퍼
class RippleClipper extends CustomClipper<Rect> {
  final double progress;

  RippleClipper(this.progress);

  @override
  Rect getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = progress * math.max(size.width, size.height);

    return Rect.fromCircle(center: center, radius: radius);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => true;
}

/// 애니메이션 타입
enum AnimationType {
  fade,
  slideUp,
  slideDown,
  slideLeft,
  slideRight,
  slideUpLeft,
  slideUpRight,
  scale,
  rotate,
  physics,
  morph,
  wave,
  ripple,
  elastic,
  bounce,
}

/// 트랜지션 타입
enum TransitionType {
  crossFade,
  slideReplace,
  scaleReplace,
  fadeReplace,
  morphReplace,
}