import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ElectricRefreshIndicator
// Drop-in replacement for Flutter's RefreshIndicator.
// Usage:
//   ElectricRefreshIndicator(
//     onRefresh: () async { /* your refresh logic */ },
//     child: ListView(...),
//   )
// ─────────────────────────────────────────────────────────────────────────────

class ElectricRefreshIndicator extends StatefulWidget {
  const ElectricRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.displacement = 80.0,
    this.color = const Color(0xFF2C2C2C), // Charcoal default
    this.backgroundColor = const Color(0xFF0A0E1A),
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final double displacement;
  final Color color;
  final Color backgroundColor;

  @override
  State<ElectricRefreshIndicator> createState() =>
      _ElectricRefreshIndicatorState();
}

class _ElectricRefreshIndicatorState extends State<ElectricRefreshIndicator>
    with TickerProviderStateMixin {
  // Pull progress: 0.0 → 1.0
  double _pullProgress = 0.0;
  bool _refreshing = false;
  bool _armed = false;

  late AnimationController _arcController;
  late AnimationController _pulseController;
  late AnimationController _collapseController;

  @override
  void initState() {
    super.initState();

    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _collapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _arcController.dispose();
    _pulseController.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  Future<void> _triggerRefresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _armed = false;
    });

    // Ensure loading animation shows for at least 2 seconds
    final stopwatch = Stopwatch()..start();
    await widget.onRefresh();
    final elapsed = stopwatch.elapsedMilliseconds;
    final remaining = 2000 - elapsed;

    if (remaining > 0 && mounted) {
      await Future.delayed(Duration(milliseconds: remaining));
    }

    if (!mounted) return;
    await _collapseController.forward();
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      _pullProgress = 0.0;
    });
    _collapseController.reset();
  }

  bool _handleNotification(ScrollNotification notification) {
    if (_refreshing) return false;

    final double pixels = notification.metrics.pixels;

    if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      if (pixels < 0) {
        setState(() {
          _pullProgress = (-pixels / widget.displacement).clamp(0.0, 1.2);
          if (_pullProgress >= 1.0) {
            _armed = true;
          }
        });
      }

      // Check for finger release while armed
      if (notification is ScrollUpdateNotification &&
          notification.dragDetails == null &&
          _armed) {
        _triggerRefresh();
      }

      if (pixels >= 0 && _pullProgress > 0) {
        if (!_armed) {
          setState(() {
            _pullProgress = 0.0;
          });
        } else if (pixels > 10) {
          setState(() {
            _pullProgress = 0.0;
            _armed = false;
          });
        }
      }
    }

    if (notification is ScrollEndNotification) {
      if (_armed) {
        _triggerRefresh();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _pullProgress = 0.0;
              _armed = false;
            });
          }
        });
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final double safeAreaOffset = topPadding > 0 ? topPadding : 15.0;
    
    // Current height logic:
    // When refreshing, it stays at displacement, then collapses.
    // When pulling, it's driven by pullProgress.
    final double currentHeight;
    final double activeOffset;
    if (_refreshing) {
      currentHeight = widget.displacement * (1.0 - _collapseController.value);
      activeOffset = safeAreaOffset * (1.0 - _collapseController.value);
    } else {
      currentHeight = (widget.displacement * _pullProgress)
          .clamp(0.0, widget.displacement * 1.2);
      activeOffset = safeAreaOffset * _pullProgress.clamp(0.0, 1.0);
    }

    return Stack(
      children: [
        // Push the child down when refreshing or pulling
        Positioned.fill(
          top: activeOffset + currentHeight.clamp(0.0, widget.displacement),
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleNotification,
            child: widget.child,
          ),
        ),

        // Indicator sits at the top, moved down for the notch smoothly
        Positioned(
          top: activeOffset,
          left: 0,
          right: 0,
          height: currentHeight.clamp(0.0, widget.displacement),
          child: ClipRect(
            child: OverflowBox(
              minHeight: widget.displacement,
              maxHeight: widget.displacement,
              alignment: Alignment.center,
              child: _ElectricArcWidget(
                progress: _refreshing ? 1.0 : _pullProgress.clamp(0.0, 1.0),
                refreshing: _refreshing,
                armed: _armed,
                arcController: _arcController,
                pulseController: _pulseController,
                color: widget.color,
                backgroundColor: widget.backgroundColor,
                size: widget.displacement,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal animated widget
// ─────────────────────────────────────────────────────────────────────────────

class _ElectricArcWidget extends StatelessWidget {
  const _ElectricArcWidget({
    required this.progress,
    required this.refreshing,
    required this.armed,
    required this.arcController,
    required this.pulseController,
    required this.color,
    required this.backgroundColor,
    required this.size,
  });

  final double progress;
  final bool refreshing;
  final bool armed;
  final AnimationController arcController;
  final AnimationController pulseController;
  final Color color;
  final Color backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([arcController, pulseController]),
      builder: (context, _) {
        return CustomPaint(
          size: Size(double.infinity, size),
          painter: _ElectricArcPainter(
            progress: progress,
            refreshing: refreshing,
            armed: armed,
            arcPhase: arcController.value,
            pulsePhase: pulseController.value,
            color: color,
            backgroundColor: backgroundColor,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter – the core electric effect
// ─────────────────────────────────────────────────────────────────────────────

class _ElectricArcPainter extends CustomPainter {
  _ElectricArcPainter({
    required this.progress,
    required this.refreshing,
    required this.armed,
    required this.arcPhase,
    required this.pulsePhase,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final bool refreshing;
  final bool armed;
  final double arcPhase;
  final double pulsePhase;
  final Color color;
  final Color backgroundColor;

  final _rng = math.Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01 && !refreshing) return;

    // Interpolate color between charcoal (color) and bright red when refreshing
    final animatedColor = refreshing
        ? Color.lerp(color, const Color(0xFFEF4444), (math.sin(pulsePhase * math.pi)).abs()) ?? color
        : color;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.height * 0.32).clamp(14.0, 28.0);

    // ── Background pill ──────────────────────────────────────────────────────
    final bgPaint = Paint()
      ..color = backgroundColor.withOpacity(0.88 * progress.clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: size.width * 0.6,
          height: size.height * 0.72,
        ),
        const Radius.circular(40),
      ),
      bgPaint,
    );

    // ── Outer glow ring (always behind) ──────────────────────────────────────
    final glowIntensity = refreshing
        ? 0.35 + 0.2 * math.sin(pulsePhase * math.pi)
        : 0.18 * progress;
    _drawGlowRing(canvas, Offset(cx, cy), radius, glowIntensity, animatedColor);

    if (refreshing) {
      _drawRefreshingState(canvas, Offset(cx, cy), radius, size, animatedColor);
    } else {
      _drawPullState(canvas, Offset(cx, cy), radius, size, animatedColor);
    }
  }

  // ── Pull state: arc that grows as you pull ──────────────────────────────────
  void _drawPullState(Canvas canvas, Offset center, double radius, Size size, Color color) {
    // Arc sweep grows with pull progress
    final sweep = progress * 2 * math.pi;
    const startAngle = -math.pi / 2;

    // Background track
    final trackPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (sweep < 0.05) return;

    // Glowing arc
    final arcPaint = Paint()
      ..color = armed ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = armed ? 3.5 : 2.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, armed ? 8.0 : 4.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      arcPaint,
    );

    // Core (no blur) on top
    final corePaint = Paint()
      ..color = armed ? Colors.white : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = armed ? 2.0 : 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      corePaint,
    );

    // Lightning bolt tip when armed
    if (armed) {
      final tipAngle = startAngle + sweep;
      final tipX = center.dx + radius * math.cos(tipAngle);
      final tipY = center.dy + radius * math.sin(tipAngle);
      _drawLightningBolt(canvas, Offset(tipX, tipY), 10.0, 1.0);
    }

    // Central bolt icon
    _drawBoltIcon(
      canvas,
      center,
      radius * 0.45,
      armed ? 1.0 : progress.clamp(0.3, 1.0),
      color,
    );
  }

  // ── Refreshing state: full spinning electric arcs ───────────────────────────
  void _drawRefreshingState(
    Canvas canvas,
    Offset center,
    double radius,
    Size size,
    Color color,
  ) {
    final t = arcPhase; // 0..1 looping

    // Outer spinning arc
    _drawSpinArc(canvas, center, radius, t, color, 2.5, 5.0, 0.7);
    // Inner counter-spinning arc
    _drawSpinArc(
      canvas,
      center,
      radius * 0.7,
      1.0 - t,
      color.withOpacity(0.6),
      1.5,
      3.0,
      0.5,
    );

    // Electric sparks
    for (int i = 0; i < 6; i++) {
      final sparkAngle = (t * 2 * math.pi) + (i * math.pi / 3);
      final sparkR = radius + 6 + 4 * math.sin(t * math.pi * 2 + i);
      final sx = center.dx + sparkR * math.cos(sparkAngle);
      final sy = center.dy + sparkR * math.sin(sparkAngle);
      _drawSpark(
        canvas,
        Offset(sx, sy),
        4.0 + 2.0 * math.sin(t * math.pi * 3 + i * 0.7),
      );
    }

    // Jagged lightning between inner and outer
    _drawArcLightning(canvas, center, radius * 0.7, radius, t, color);

    // Central pulsing bolt
    final boltScale = 0.4 + 0.1 * math.sin(pulsePhase * math.pi);
    _drawBoltIcon(canvas, center, radius * boltScale, 1.0, color);
  }

  // ── Spinning arc helper ─────────────────────────────────────────────────────
  void _drawSpinArc(
    Canvas canvas,
    Offset center,
    double radius,
    double t,
    Color c,
    double strokeW,
    double blurR,
    double opacity,
  ) {
    const sweepFraction = 0.65;
    final startAngle = t * 2 * math.pi;
    final sweep = sweepFraction * 2 * math.pi;

    final glowPaint = Paint()
      ..color = c.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW + 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurR);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      glowPaint,
    );

    final corePaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      corePaint,
    );
  }

  // ── Jagged lightning arcing between two radii ───────────────────────────────
  void _drawArcLightning(
    Canvas canvas,
    Offset center,
    double r1,
    double r2,
    double t,
    Color color,
  ) {
    final numBolts = 3;
    for (int b = 0; b < numBolts; b++) {
      final baseAngle = t * 2 * math.pi + b * (2 * math.pi / numBolts);

      // Build a jagged path from r1 to r2 along this angle ± small variance
      final path = Path();
      const segments = 5;
      Offset? prev;
      for (int s = 0; s <= segments; s++) {
        final frac = s / segments;
        final r = r1 + (r2 - r1) * frac;
        final jitter = s == 0 || s == segments
            ? 0.0
            : (0.15 * ((_rng.nextDouble() * 2 - 1)));
        final angle = baseAngle + jitter;
        final pt = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (s == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
        prev = pt;
      }

      final p = Paint()
        ..color = color.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawPath(path, p);
    }
  }

  // ── Outer glow ring ─────────────────────────────────────────────────────────
  void _drawGlowRing(
    Canvas canvas,
    Offset center,
    double radius,
    double intensity,
    Color color,
  ) {
    final paint = Paint()
      ..color = color.withOpacity(intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawCircle(center, radius, paint);
  }

  // ── Small spark dot ─────────────────────────────────────────────────────────
  void _drawSpark(Canvas canvas, Offset pos, double size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.5);
    canvas.drawCircle(pos, size * 0.4, p);
  }

  // ── Lightning bolt icon in the center ──────────────────────────────────────
  void _drawBoltIcon(
    Canvas canvas,
    Offset center,
    double halfH,
    double opacity,
    Color color,
  ) {
    final w = halfH * 0.65;
    final path = Path()
      ..moveTo(center.dx + w * 0.15, center.dy - halfH)
      ..lineTo(center.dx - w * 0.5, center.dy + halfH * 0.05)
      ..lineTo(center.dx + w * 0.08, center.dy + halfH * 0.05)
      ..lineTo(center.dx - w * 0.15, center.dy + halfH)
      ..lineTo(center.dx + w * 0.5, center.dy - halfH * 0.05)
      ..lineTo(center.dx - w * 0.08, center.dy - halfH * 0.05)
      ..close();

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.5 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Fill
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.95 * opacity));
    // White core
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.35 * opacity)
        ..blendMode = BlendMode.plus,
    );
  }

  // ── Small lightning bolt at arc tip ────────────────────────────────────────
  void _drawLightningBolt(
    Canvas canvas,
    Offset pos,
    double halfH,
    double opacity,
  ) {
    final w = halfH * 0.65;
    final path = Path()
      ..moveTo(pos.dx + w * 0.15, pos.dy - halfH)
      ..lineTo(pos.dx - w * 0.5, pos.dy)
      ..lineTo(pos.dx + w * 0.08, pos.dy)
      ..lineTo(pos.dx - w * 0.15, pos.dy + halfH)
      ..lineTo(pos.dx + w * 0.5, pos.dy)
      ..lineTo(pos.dx - w * 0.08, pos.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.9 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(path, Paint()..color = Colors.white.withOpacity(opacity));
  }

  @override
  bool shouldRepaint(_ElectricArcPainter old) =>
      old.progress != progress ||
      old.refreshing != refreshing ||
      old.armed != armed ||
      old.arcPhase != arcPhase ||
      old.pulsePhase != pulsePhase;
}

// ─────────────────────────────────────────────────────────────────────────────
// Demo app – shows the widget in action
// ─────────────────────────────────────────────────────────────────────────────

void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Electric Refresh Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B15),
      ),
      home: const _DemoPage(),
    );
  }
}

class _DemoPage extends StatefulWidget {
  const _DemoPage();

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  int _refreshCount = 0;

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) setState(() => _refreshCount++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0E1A),
        title: const Text(
          '⚡ Electric Refresh',
          style: TextStyle(
            color: Color(0xFF00E5FF),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        elevation: 0,
      ),
      body: ElectricRefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: 20,
          itemBuilder: (ctx, i) =>
              _GridCard(index: i, refreshCount: _refreshCount),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  const _GridCard({required this.index, required this.refreshCount});
  final int index;
  final int refreshCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1A2540), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00E5FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Item #${index + 1}  •  refresh $refreshCount',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pull down to see the electric arc ⚡',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
