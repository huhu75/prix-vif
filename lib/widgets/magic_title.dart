import 'package:flutter/material.dart';
import '../theme.dart';

// Titre avec effet IA magique (style futuriste mais élégant)
class MagicTitle extends StatefulWidget {
  final String text;
  final double fontSize;
  final bool showGlow;
  final TextStyle? style;

  const MagicTitle({
    super.key,
    required this.text,
    this.fontSize = 24,
    this.showGlow = true,
    this.style,
  });

  @override
  State<MagicTitle> createState() => _MagicTitleState();
}

class _MagicTitleState extends State<MagicTitle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _colorAnimation = ColorTween(
      begin: AppTheme.primary.withOpacity(0.9),
      end: AppTheme.accent.withOpacity(1.0),
    ).animate(
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
    if (!widget.showGlow) {
      return Text(
        widget.text,
        style: widget.style ?? TextStyle(
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Glow effect
            Text(
              widget.text,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.bold,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.0
                  ..color = _colorAnimation.value!.withOpacity(0.5 * _glowAnimation.value),
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: _colorAnimation.value!.withOpacity(0.3),
                    blurRadius: _glowAnimation.value * 10,
                    offset: Offset.zero,
                  ),
                  Shadow(
                    color: _colorAnimation.value!.withOpacity(0.2),
                    blurRadius: _glowAnimation.value * 15,
                    offset: Offset.zero,
                  ),
                ],
              ),
            ),
            // Main text
            Text(
              widget.text,
              style: widget.style ?? TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: _colorAnimation.value!.withOpacity(0.2),
                    blurRadius: 5,
                    offset: Offset.zero,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Titre avec effet de particle/glitch subtil
class AITitle extends StatefulWidget {
  final String text;
  final double fontSize;
  final IconData? icon;

  const AITitle({
    super.key,
    required this.text,
    this.fontSize = 24,
    this.icon,
  });

  @override
  State<AITitle> createState() => _AITitleState();
}

class _AITitleState extends State<AITitle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(-0.02, 0),
      end: const Offset(0.02, 0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          SlideTransition(
            position: _offsetAnimation,
            child: Icon(
              widget.icon!,
              size: widget.fontSize * 0.8,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
        SlideTransition(
          position: _offsetAnimation,
          child: Opacity(
            opacity: _opacityAnimation,
            child: Text(
              widget.text,
              style: TextStyle(
                fontSize: widget.fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Titre avec effet de scan (pour l'écran Scanner)
class ScannerTitle extends StatelessWidget {
  final String text;

  const ScannerTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background glow
        Text(
          text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0
              ..color = AppTheme.primary.withOpacity(0.3),
            letterSpacing: 2.0,
          ),
        ),
        // Main text
        Text(
          text,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 2.0,
          ),
        ),
        // Scan line effect (top)
        Positioned(
          top: -8,
          child: Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        // Scan line effect (bottom)
        Positioned(
          bottom: -8,
          child: Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ],
    );
  }
}

// AppBar personnalisée avec effet IA
class AIAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;

  const AIAppBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: leading,
      actions: actions,
      title: ScannerTitle(text: title),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

// Titre avec effet de néon subtil
class NeonTitle extends StatelessWidget {
  final String text;
  final double fontSize;

  const NeonTitle({
    super.key,
    required this.text,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Neon glow (multiple layers)
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0
              ..color = AppTheme.primary.withOpacity(0.4),
            letterSpacing: 1.5,
            shadows: [
              Shadow(
                color: AppTheme.primary,
                blurRadius: 15,
                offset: Offset.zero,
              ),
              Shadow(
                color: AppTheme.primary,
                blurRadius: 25,
                offset: Offset.zero,
              ),
            ],
          ),
        ),
        // Main text
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}
