import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Swipe-to-Confirm button (Enhanced with Timer) ────────────────────────────
class SwipeToConfirm extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final bool enabled;
  final VoidCallback onConfirmed;
  final int countdown;

  const SwipeToConfirm({
    Key? key,
    required this.label,
    required this.icon,
    this.color = const Color(0xFF22C55E),
    this.loading = false,
    this.enabled = true,
    required this.onConfirmed,
    this.countdown = 0,
  }) : super(key: key);

  @override
  State<SwipeToConfirm> createState() => _SwipeToConfirmState();
}

class _SwipeToConfirmState extends State<SwipeToConfirm> with TickerProviderStateMixin {
  final _posNotifier = ValueNotifier<double>(0.0);
  bool _triggered = false;

  late final AnimationController _arrowCtrl;
  late final List<Animation<double>> _arrowAnims;
  late final AnimationController _loadingCtrl;
  late final Animation<double> _loadingAnim;
  AnimationController? _snapCtrl;

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

    _arrowAnims = List.generate(3, (i) {
      final start = i * 0.15;
      final end = (start + 0.70).clamp(0.0, 1.0);
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.25, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.25).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
      ]).animate(CurvedAnimation(parent: _arrowCtrl, curve: Interval(start, end)));
    });

    _loadingCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _loadingAnim = CurvedAnimation(parent: _loadingCtrl, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(SwipeToConfirm old) {
    super.didUpdateWidget(old);
    if (widget.loading && !old.loading) {
      _arrowCtrl.stop();
      _loadingCtrl.forward(from: 0.0);
    }
    // Only snap back if the loading state finished (was true, now false)
    if (!widget.loading && old.loading) {
      _loadingCtrl.stop();
      _snapBack();
    }
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    _loadingCtrl.dispose();
    _posNotifier.dispose();
    _snapCtrl?.dispose();
    super.dispose();
  }

  bool _isDragging = false;

  void _onPanStart(DragStartDetails d) {
    if (widget.loading || !widget.enabled) return;
    _isDragging = true;
  }

  void _onPanUpdate(DragUpdateDetails d, double maxSwipe) {
    if (_triggered || widget.loading || maxSwipe <= 0) return;
    final newPos = (_posNotifier.value + d.delta.dx).clamp(0.0, maxSwipe);
    _posNotifier.value = newPos;

    // Trigger confirmation when 85% of the swipe is complete
    if (newPos >= maxSwipe * 0.98) {
      _triggered = true;
      setState(() {});
      
      // Animate the remaining 15% for a smooth finish
      final startPos = _posNotifier.value;
      final finishCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
      final finishAnim = CurvedAnimation(parent: finishCtrl, curve: Curves.easeOut);
      finishAnim.addListener(() {
        _posNotifier.value = startPos + (maxSwipe - startPos) * finishAnim.value;
      });
      finishCtrl.forward().then((_) => finishCtrl.dispose());

      HapticFeedback.heavyImpact();
      widget.onConfirmed();
      
      // Only snap back if the parent didn't set loading to true AND the user released the thumb
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !widget.loading && _triggered && !_isDragging) _snapBack();
      });
    }
  }

  void _snapBack() {
    _triggered = false;
    setState(() {});
    _arrowCtrl.repeat();
    if (_posNotifier.value <= 0) return;
    final startPos = _posNotifier.value;
    _snapCtrl?.stop();
    _snapCtrl?.dispose();
    _snapCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    final curve = CurvedAnimation(parent: _snapCtrl!, curve: Curves.easeOutBack);
    curve.addListener(() => _posNotifier.value = startPos * (1 - curve.value));
    _snapCtrl!.forward();
  }

  void _onPanEnd(DragEndDetails d, double maxSwipe) {
    _isDragging = false;
    if (_triggered || widget.loading || maxSwipe <= 0) {
      // If triggered and we just ended, we might want to snap back if not loading
      if (_triggered && !widget.loading) _snapBack();
      return;
    }
    final velocity = d.velocity.pixelsPerSecond.dx;
    if (velocity > 800 && _posNotifier.value >= maxSwipe * 0.5) {
      _triggered = true;
      setState(() {});
      HapticFeedback.heavyImpact();
      widget.onConfirmed();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !widget.loading && _triggered && !_isDragging) _snapBack();
      });
      return;
    }
    _snapBack();
  }

  void _onPanCancel() {
    _isDragging = false;
    if (!_triggered && !widget.loading) _snapBack();
  }

  @override
  Widget build(BuildContext context) {
    final color = (widget.loading || !widget.enabled) ? Colors.grey : widget.color;
    return LayoutBuilder(builder: (ctx, constraints) {
      final maxSwipe = (constraints.maxWidth - 56.0).clamp(0.0, double.infinity);

      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Loading Progress Fill (Simulated)
            if (widget.loading)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _loadingAnim,
                  builder: (context, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _loadingAnim.value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
              ),

            // Track Fill
            ValueListenableBuilder<double>(
              valueListenable: _posNotifier,
              builder: (_, pos, __) => Positioned(
                left: 0, top: 0, bottom: 0,
                width: (pos + 56).clamp(56.0, constraints.maxWidth),
                child: DecoratedBox(decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(28))),
              ),
            ),

            // Label
            ValueListenableBuilder<double>(
              valueListenable: _posNotifier,
              builder: (_, pos, __) {
                final opacity = (maxSwipe <= 0) ? 1.0 : (1.0 - (pos / maxSwipe) * 2.5).clamp(0.0, 1.0);
                return Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Text(
                      widget.loading ? 'Processing…' : widget.label,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color.withOpacity(0.8), letterSpacing: -0.2),
                    ),
                  ),
                );
              },
            ),

            // Guiding Arrows
            ValueListenableBuilder<double>(
              valueListenable: _posNotifier,
              builder: (_, pos, __) {
                final t = (maxSwipe <= 0) ? 0.0 : (pos / maxSwipe).clamp(0.0, 1.0);
                final containerOpacity = (1.0 - t * 3.0).clamp(0.0, 1.0);
                return Positioned(
                  right: 20, top: 0, bottom: 0,
                  child: Opacity(
                    opacity: containerOpacity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) => AnimatedBuilder(
                        animation: _arrowAnims[i],
                        builder: (_, __) {
                          final v = _arrowAnims[i].value;
                          return Opacity(
                            opacity: v,
                            child: Transform.translate(offset: Offset((v - 0.25) * 5, 0), child: Icon(Icons.chevron_right_rounded, size: 16.0 + i * 4.5, color: color.withOpacity(0.4 + i * 0.2))),
                          );
                        },
                      )),
                    ),
                  ),
                );
              },
            ),

            // Thumb with Timer Indicator
            ValueListenableBuilder<double>(
              valueListenable: _posNotifier,
              builder: (context, pos, child) {
                final isCritical = widget.countdown > 0 && widget.countdown <= 10;
                final timerProgress = (widget.countdown / 60.0).clamp(0.0, 1.0);
                final thumbColor = isCritical ? Colors.red : color;

                return Positioned(
                  left: 4 + pos, top: 4, bottom: 4,
                  child: AbsorbPointer(
                    absorbing: _triggered || widget.loading,
                    child: GestureDetector(
                      onHorizontalDragStart: _onPanStart,
                      onHorizontalDragUpdate: (d) => _onPanUpdate(d, maxSwipe),
                      onHorizontalDragEnd: (d) => _onPanEnd(d, maxSwipe),
                      onHorizontalDragCancel: _onPanCancel,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (widget.countdown > 0 && !widget.loading)
                            CustomPaint(
                              size: const Size(48, 48),
                              painter: _TimerProgressPainter(progress: timerProgress, isWarning: isCritical, color: color),
                            ),
                          Container(
                            width: 48,
                            decoration: BoxDecoration(
                              color: widget.loading ? thumbColor.withOpacity(0.6) : thumbColor,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: thumbColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
                            ),
                            child: Center(
                              child: widget.loading
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (widget.countdown > 0)
                                          Text('${widget.countdown}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, height: 1.1)),
                                        Icon(widget.icon, color: Colors.white, size: widget.countdown > 0 ? 16 : 24),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }
}

// ─── Timer Progress Painter ────────────────────────
class _TimerProgressPainter extends CustomPainter {
  final double progress;
  final bool isWarning;
  final Color color;

  _TimerProgressPainter({required this.progress, required this.isWarning, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 2.5;
    final Paint progressPaint = Paint()
      ..color = isWarning ? Colors.red : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Paint backgroundPaint = Paint()
      ..color = (isWarning ? Colors.red : color).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - (strokeWidth / 2);

    // Draw background circle
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw progress arc
    final Rect rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -3.14159 / 2, // Start from top
      (progress * 2 * 3.14159), // Sweep angle based on progress
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_TimerProgressPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        isWarning != oldDelegate.isWarning;
  }
}
