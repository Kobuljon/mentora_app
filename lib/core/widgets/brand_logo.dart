import 'package:flutter/material.dart';

class MentoraLogo extends StatelessWidget {
  const MentoraLogo({
    super.key,
    this.size = 40,
    this.padding = 0,
    this.backgroundColor,
    this.borderRadius,
  });

  final double size;
  final double padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final innerSize = size - (padding * 2);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: backgroundColor == null
          ? null
          : BoxDecoration(
              color: backgroundColor,
              borderRadius: borderRadius ?? BorderRadius.circular(size * 0.24),
            ),
      child: Image.asset(
        'assets/icon/logo.png',
        width: innerSize,
        height: innerSize,
        fit: BoxFit.contain,
      ),
    );
  }
}

class MentoraLogoLoader extends StatefulWidget {
  const MentoraLogoLoader({super.key, this.size = 28});

  final double size;

  @override
  State<MentoraLogoLoader> createState() => _MentoraLogoLoaderState();
}

class _MentoraLogoLoaderState extends State<MentoraLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: MentoraLogo(size: widget.size),
    );
  }
}
