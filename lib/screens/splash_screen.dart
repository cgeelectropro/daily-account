import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';

/// A sacred, illuminated-manuscript-style splash screen.
/// Golden cross with radiating light, ornamental rings, and elegant typography
/// that fades in with staggered animations before transitioning to HomeShell.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _rayController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _rayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Navigate after splash animation completes
    Future.delayed(const Duration(milliseconds: 3200), () async {
      if (!mounted) return;
      final done = await StorageService.instance.getSetting('onboarding_complete');
      if (!mounted) return;
      final destination = done == 'true' ? const HomeShell() : const OnboardingScreen();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => destination,
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (_, anim, __, child) {
            return FadeTransition(opacity: anim, child: child);
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    _rayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Animated icon area ──
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Slow rotating rays
                    AnimatedBuilder(
                      animation: _rayController,
                      builder: (_, __) => CustomPaint(
                        size: const Size(220, 220),
                        painter: _RayPainter(
                          rotation: _rayController.value * 2 * math.pi,
                        ),
                      ),
                    ),
                    // Pulsing glow
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (_, __) => Container(
                        width: 130 + _glowController.value * 20,
                        height: 130 + _glowController.value * 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.gold.withOpacity(0.12 + _glowController.value * 0.06),
                              AppTheme.goldDeep.withOpacity(0.04),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Outer ornamental ring
                    CustomPaint(
                      size: const Size(180, 180),
                      painter: _OrnamentRingPainter(radius: 85),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.6, 0.6),
                          end: const Offset(1.0, 1.0),
                          duration: 1200.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 800.ms),
                    // Inner ornamental ring
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: _OrnamentRingPainter(radius: 65),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.5, 0.5),
                          end: const Offset(1.0, 1.0),
                          duration: 1000.ms,
                          delay: 200.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 600.ms, delay: 200.ms),
                    // Golden Cross
                    CustomPaint(
                      size: const Size(100, 130),
                      painter: _CrossPainter(),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.0, 0.0),
                          end: const Offset(1.0, 1.0),
                          duration: 800.ms,
                          delay: 400.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 600.ms, delay: 400.ms),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              // ── App title ──
              Builder(builder: (context) {
                final l = S.of(context);
                return Column(
                  children: [
                    Text(
                      l.appTitle,
                      style: AppTheme.display(32, color: AppTheme.gold),
                    )
                        .animate()
                        .fadeIn(duration: 800.ms, delay: 900.ms)
                        .slideY(begin: 0.3, end: 0, duration: 800.ms, delay: 900.ms,
                            curve: Curves.easeOut),
                    const SizedBox(height: 8),
                    // ── Tagline ──
                    Text(
                      l.walkWithGod,
                      style: AppTheme.label(12, color: AppTheme.clay),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 1300.ms)
                        .slideY(begin: 0.4, end: 0, duration: 600.ms, delay: 1300.ms,
                            curve: Curves.easeOut),
                    const SizedBox(height: 6),
                    Text(
                      l.cmfiDiscipline,
                      style: AppTheme.label(10, color: AppTheme.clay.withOpacity(0.6)),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 1500.ms),
                    const SizedBox(height: 48),
                    // ── Scripture verse ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        l.splashVerse,
                        textAlign: TextAlign.center,
                        style: AppTheme.serif(13,
                            color: AppTheme.sand, style: FontStyle.italic),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 800.ms, delay: 1800.ms),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paints slowly rotating subtle gold rays emanating from center.
class _RayPainter extends CustomPainter {
  final double rotation;
  _RayPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            AppTheme.gold.withOpacity(0.0),
            AppTheme.gold.withOpacity(i.isEven ? 0.07 : 0.03),
            AppTheme.gold.withOpacity(0.0),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
        ..strokeWidth = i.isEven ? 1.8 : 0.8
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        center + Offset(math.cos(angle) * 25, math.sin(angle) * 25),
        center + Offset(math.cos(angle) * maxRadius, math.sin(angle) * maxRadius),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RayPainter old) => old.rotation != rotation;
}

/// Paints a decorative dotted ring with small ornamental markers.
class _OrnamentRingPainter extends CustomPainter {
  final double radius;
  _OrnamentRingPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    // Main ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppTheme.gold.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Small ornament dots on the ring
    final dotPaint = Paint()..color = AppTheme.gold.withOpacity(0.5);
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final pos = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawCircle(pos, 2.2, dotPaint);
    }

    // Tiny diamond at cardinal points
    final diamondPaint = Paint()..color = AppTheme.gold.withOpacity(0.35);
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 + math.pi / 4;
      final pos = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      const d = 3.5;
      final path = Path()
        ..moveTo(pos.dx, pos.dy - d)
        ..lineTo(pos.dx + d, pos.dy)
        ..lineTo(pos.dx, pos.dy + d)
        ..lineTo(pos.dx - d, pos.dy)
        ..close();
      canvas.drawPath(path, diamondPaint);
    }
  }

  @override
  bool shouldRepaint(_OrnamentRingPainter old) => false;
}

/// Paints a beautiful golden cross with 3D-style shading.
class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final beamW = size.width * 0.18;
    final vTop = size.height * 0.05;
    final vBot = size.height * 0.95;
    final hLeft = size.width * 0.02;
    final hRight = size.width * 0.98;
    final hTop = cy - beamW / 2 - size.height * 0.04;
    final hBot = cy + beamW / 2 - size.height * 0.04;
    final r = beamW * 0.15;

    // Cross shadow
    final shadowPaint = Paint()
      ..color = const Color(0x50000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - beamW / 2 + 2, vTop + 2, cx + beamW / 2 + 2, vBot + 2),
        Radius.circular(r),
      ),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(hLeft + 2, hTop + 2, hRight + 2, hBot + 2),
        Radius.circular(r),
      ),
      shadowPaint,
    );

    // Main cross gradient
    final crossPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.goldSoft, AppTheme.gold, AppTheme.goldDeep],
        stops: [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTRB(hLeft, vTop, hRight, vBot));

    // Vertical beam
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - beamW / 2, vTop, cx + beamW / 2, vBot),
        Radius.circular(r),
      ),
      crossPaint,
    );

    // Horizontal beam
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(hLeft, hTop, hRight, hBot),
        Radius.circular(r),
      ),
      crossPaint,
    );

    // Highlight on left edge
    final highlightPaint = Paint()
      ..color = AppTheme.goldSoft.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx - beamW / 2, vTop + r),
      Offset(cx - beamW / 2, vBot - r),
      highlightPaint,
    );

    // Highlight on top edge of horizontal beam
    canvas.drawLine(
      Offset(hLeft + r, hTop),
      Offset(hRight - r, hTop),
      highlightPaint,
    );

    // Intersection glow
    canvas.drawRect(
      Rect.fromLTRB(cx - beamW / 2, hTop, cx + beamW / 2, hBot),
      Paint()..color = AppTheme.goldSoft.withOpacity(0.15),
    );
  }

  @override
  bool shouldRepaint(_CrossPainter old) => false;
}
