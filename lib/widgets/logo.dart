import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Widget pour afficher le logo Prix Vif
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;

  const AppLogo({
    super.key,
    this.size = 40,
    this.showText = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo SVG
        SvgPicture.asset(
          'assets/images/app_icon.svg',
          width: size,
          height: size,
          colorFilter: color != null
              ? ColorFilter.mode(color!, BlendMode.srcIn)
              : null,
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          // Texte "Prix Vif"
          const Text(
            'Prix Vif',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

// Logo avec effet d'animation
class AnimatedLogo extends StatefulWidget {
  final double size;
  final bool showText;
  final Duration duration;

  const AnimatedLogo({
    super.key,
    this.size = 60,
    this.showText = true,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _rotationAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform(
          transform: Matrix4.identity()
            ..scale(_scaleAnimation.value)
            ..rotateZ(_rotationAnimation.value * 0.0174533), // Convert to radians
          alignment: Alignment.center,
          child: AppLogo(
            size: widget.size,
            showText: widget.showText,
          ),
        );
      },
    );
  }
}

// Icône de l'application (pour AppBar)
class AppIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const AppIcon({
    super.key,
    this.size = 28,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/app_icon.svg',
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
