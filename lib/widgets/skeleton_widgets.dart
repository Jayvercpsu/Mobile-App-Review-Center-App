import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = AppPalette.primary.withValues(alpha: 0.08);
    final Color highlight = Colors.white.withValues(alpha: 0.7);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double slide = _controller.value * 2 - 1;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect rect) {
            return LinearGradient(
              begin: Alignment(-1 + slide, 0),
              end: Alignment(1 + slide, 0),
              colors: <Color>[base, highlight, base],
              stops: const <double>[0.1, 0.5, 0.9],
            ).createShader(rect);
          },
          child: widget.child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    required this.height,
    required this.width,
    this.borderRadius = 10,
  }) : _isCircle = false;

  const SkeletonBox.circle({super.key, required double size})
    : height = size,
      width = size,
      borderRadius = 999,
      _isCircle = true;

  final double height;
  final double width;
  final double borderRadius;
  final bool _isCircle;

  @override
  Widget build(BuildContext context) {
    final Color base = AppPalette.primary.withValues(alpha: 0.08);
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: base,
        borderRadius: _isCircle
            ? BorderRadius.circular(999)
            : BorderRadius.circular(borderRadius),
      ),
    );
  }
}
