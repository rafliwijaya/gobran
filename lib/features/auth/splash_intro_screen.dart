import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

/// Animated 4000ms intro splash screen for Go-Bran using only built-in Flutter
/// primitives (`SingleTickerProviderStateMixin`, `Interval`, `AnimatedBuilder`,
/// `RepaintBoundary`, `CustomPainter`, and `ClipRect`).
class GoBranSplashIntroScreen extends StatefulWidget {
  const GoBranSplashIntroScreen({
    this.nextPage,
    this.onFinished,
    super.key,
  });

  /// Optional target page to transition into with a fade [PageRouteBuilder]
  /// when the 4000ms animation completes.
  final Widget? nextPage;

  /// Optional callback invoked when the intro animation finishes.
  final VoidCallback? onFinished;

  @override
  State<GoBranSplashIntroScreen> createState() =>
      _GoBranSplashIntroScreenState();
}

class _GoBranSplashIntroScreenState extends State<GoBranSplashIntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Phase 1 (0.0 - 1.0s => 0.00 - 0.25): Rider enters from left + speedlines
  late final Animation<double> _enterAnim;
  late final Animation<double> _speedlineIn;
  late final Animation<double> _speedlineOut;

  // Phase 2 (1.0 - 1.8s => 0.25 - 0.45): Anticipation, shrink to ~45% & move up
  late final Animation<double> _anticipationAnim;
  late final Animation<double> _shrinkAndRiseAnim;
  late final Animation<double> _springSettleAnim;

  // Phase 3 (1.5 - 2.5s => 0.375 - 0.625): Text wipe left-to-right + 20px slide + fade
  late final Animation<double> _textWipeAnim;
  late final Animation<double> _textFadeAnim;

  // Phase 4 (2.5 - 3.2s => 0.625 - 0.80): Hold with ±2px suspension & 1.0->1.02 pulse
  late final Animation<double> _holdAnim;

  // Phase 5 (3.2 - 4.0s => 0.80 - 1.00): Primary circle expands from center to fill screen
  late final Animation<double> _circleExpandAnim;

  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    _enterAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOutCubic),
    );
    _speedlineIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.10, curve: Curves.easeOut),
    );
    _speedlineOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.09, 0.27, curve: Curves.easeInOutCubic),
    );

    _anticipationAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.31, curve: Curves.easeInOutCubic),
    );
    _shrinkAndRiseAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.29, 0.45, curve: Curves.easeInOutCubic),
    );
    _springSettleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.41, 0.50, curve: Curves.easeOut),
    );

    _textWipeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.375, 0.625, curve: Curves.easeOutCubic),
    );
    _textFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.375, 0.56, curve: Curves.easeOut),
    );

    _holdAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.625, 0.80, curve: Curves.easeInOutSine),
    );

    _circleExpandAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.80, 1.0, curve: Curves.easeInOutCubic),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        _completed = true;
        _handleFinished();
      }
    });

    _controller.forward();
  }

  void _handleFinished() {
    widget.onFinished?.call();
    final target = widget.nextPage;
    if (target != null && mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, _, _) => target,
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenW = screenSize.width;
    final screenH = screenSize.height;
    final riderBaseSize = screenW * 0.68;
    final textWidth = screenW * 0.64;
    final textHeight = textWidth * (341 / 1024);
    final maxCircleRadius = math.sqrt(screenW * screenW + screenH * screenH);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;

            // 1. Horizontal position of rider:
            // Enters from -0.95 * screenW -> 0, then pulls back -12px during anticipation
            final enterDx = (1.0 - _enterAnim.value) * (-screenW * 0.95);
            final anticipationWave = math.sin(_anticipationAnim.value * math.pi);
            final anticipationDx = -12.0 * anticipationWave;
            final riderDx = enterDx + anticipationDx;

            // 2. Scale & vertical position of rider:
            // Starts at 68% screenW (scale 1.0) and shrinks to 40% screenW
            const targetScaleRatio = 0.40 / 0.68;
            final shrinkT = _shrinkAndRiseAnim.value;
            final baseScale = 1.0 - (1.0 - targetScaleRatio) * shrinkT;

            // Spring overshoot at the end of shrink/rise (damped oscillation)
            final settleT = _springSettleAnim.value;
            final springWave = settleT > 0 && settleT < 1.0
                ? math.sin(settleT * math.pi * 2.5) *
                      math.pow(1.0 - settleT, 1.8)
                : 0.0;

            // Vertical movement: rises up so text fits underneath, with spring overshoot + suspension bob
            final targetRiseDy = -screenH * 0.065;
            final riseDy = targetRiseDy * shrinkT + (springWave * -8.0);
            final suspensionDy = (t >= 0.625 && t <= 0.82)
                ? math.sin(_holdAnim.value * math.pi * 4.0) * 2.0
                : 0.0;
            final riderDy = riseDy + suspensionDy;

            // 3. Squash & stretch + tilt:
            // Stretches horizontally while speeding in, compresses slightly when braking,
            // tilts slightly back during anticipation.
            double squashX = 1.0;
            double squashY = 1.0;
            if (t < 0.18) {
              final accel = math.sin((t / 0.18) * math.pi);
              squashX = 1.0 + 0.07 * accel;
              squashY = 1.0 - 0.05 * accel;
            } else if (t >= 0.18 && t < 0.26) {
              final brake = math.sin(((t - 0.18) / 0.08) * math.pi);
              squashX = 1.0 - 0.05 * brake;
              squashY = 1.0 + 0.04 * brake;
            } else if (settleT > 0 && settleT < 1.0) {
              squashX = 1.0 - 0.025 * springWave;
              squashY = 1.0 + 0.025 * springWave;
            }

            // Hold pulse (1.0 -> 1.02) applied to whole logo in Phase 4
            final holdPulse = (t >= 0.625 && t <= 0.82)
                ? 1.0 + 0.02 * math.sin(_holdAnim.value * math.pi)
                : 1.0;

            final riderTilt = -0.075 * anticipationWave + (0.02 * springWave);

            // 4. Text wipe + slide + follow-through
            final wipeFactor = _textWipeAnim.value.clamp(0.0, 1.0);
            final textSlideDx = (1.0 - wipeFactor) * 20.0;
            final textOpacity = _textFadeAnim.value.clamp(0.0, 1.0);

            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                // Speedlines behind rider during Phase 1
                if (t < 0.28)
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _SpeedlinesPainter(
                        appearProgress: _speedlineIn.value,
                        fadeOutProgress: _speedlineOut.value,
                      ),
                    ),
                  ),

                // Combined Logo Group (Rider + Go-Bran Text)
                Center(
                  child: Transform.scale(
                    scale: holdPulse,
                    child: SizedBox(
                      width: screenW,
                      height: screenH * 0.52,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Go-Bran Text (Phase 3 wipe from left to right + 20px slide)
                          if (wipeFactor > 0.001)
                            Positioned(
                              top: (screenH * 0.195) + (screenW * 0.155),
                              child: Opacity(
                                opacity: textOpacity,
                                child: Transform.translate(
                                  offset: Offset(textSlideDx, 0),
                                  child: ClipRect(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: wipeFactor,
                                      child: Image.asset(
                                        'web/icons/gobran.png',
                                        width: textWidth,
                                        height: textHeight,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Ojol Rider (Phases 1-4)
                          Transform.translate(
                            offset: Offset(riderDx, riderDy),
                            child: Transform.rotate(
                              angle: riderTilt,
                              child: Transform.scale(
                                scaleX: baseScale * squashX,
                                scaleY: baseScale * squashY,
                                child: Image.asset(
                                  'web/icons/ojol.png',
                                  width: riderBaseSize,
                                  height: riderBaseSize,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Phase 5: Expanding primary green circle from logo center
                if (_circleExpandAnim.value > 0.0)
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _CircleExpandPainter(
                        radius: _circleExpandAnim.value * maxCircleRadius,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SpeedlinesPainter extends CustomPainter {
  const _SpeedlinesPainter({
    required this.appearProgress,
    required this.fadeOutProgress,
  });

  final double appearProgress;
  final double fadeOutProgress;

  static const _lines = [
    (yFactor: 0.40, delay: 0.00, lengthFactor: 0.36, stroke: 3.5),
    (yFactor: 0.46, delay: 0.06, lengthFactor: 0.48, stroke: 4.5),
    (yFactor: 0.53, delay: 0.12, lengthFactor: 0.32, stroke: 3.0),
    (yFactor: 0.58, delay: 0.04, lengthFactor: 0.42, stroke: 4.0),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in _lines) {
      final localIn = ((appearProgress - line.delay) / (1.0 - line.delay))
          .clamp(0.0, 1.0);
      final localOut = ((fadeOutProgress - line.delay) / (1.0 - line.delay))
          .clamp(0.0, 1.0);
      if (localIn <= 0.0 || localOut >= 1.0) continue;

      final alpha = (localIn * (1.0 - localOut) * 0.65).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = AppColors.primaryDark.withValues(alpha: alpha)
        ..strokeWidth = line.stroke
        ..strokeCap = StrokeCap.round;

      final y = size.height * line.yFactor;
      // Moves right at start, then elongates backward to the left as rider slows
      final headX = size.width * (0.15 + 0.42 * localIn - 0.12 * localOut);
      final tailLength =
          size.width * line.lengthFactor * (0.5 + 0.9 * localOut);
      final tailX = (headX - tailLength).clamp(0.0, size.width);

      canvas.drawLine(Offset(tailX, y), Offset(headX, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedlinesPainter oldDelegate) =>
      oldDelegate.appearProgress != appearProgress ||
      oldDelegate.fadeOutProgress != fadeOutProgress;
}

class _CircleExpandPainter extends CustomPainter {
  const _CircleExpandPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _CircleExpandPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}
