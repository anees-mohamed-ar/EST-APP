import 'package:flutter/material.dart';

class ShimmerEffect extends StatefulWidget {
  final Widget child;

  const ShimmerEffect({required this.child, Key? key}) : super(key: key);

  @override
  _ShimmerEffectState createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            widget.child,
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.0),
                    Colors.white.withOpacity(0.8),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: [0.0, 0.5, 1.0],
                  begin: Alignment(_animation.value - 1, 0),
                  end: Alignment(_animation.value + 1, 0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ShimmerText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const ShimmerText({required this.text, required this.style, Key? key})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(child: Text(text, style: style));
  }
}
