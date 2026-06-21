import 'package:flutter/material.dart';
import '../theme.dart';

// Bouton Magique avec effet Halo (style IA/Gemini)
class MagicButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isPrimary;
  final Color? color;
  final double width;
  final double height;

  const MagicButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isPrimary = true,
    this.color,
    this.width = double.infinity,
    this.height = 60,
  });

  @override
  State<MagicButton> createState() => _MagicButtonState();
}

class _MagicButtonState extends State<MagicButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
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
    final buttonColor = widget.color ?? (widget.isPrimary ? AppTheme.primary : AppTheme.secondary);
    
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Halo lumineux (effet IA)
                if (!_isHovered && !widget.isLoading)
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: buttonColor.withOpacity(0.3),
                            blurRadius: _glowAnimation.value * 20,
                            spreadRadius: _glowAnimation.value * 4,
                          ),
                          BoxShadow(
                            color: buttonColor.withOpacity(0.2),
                            blurRadius: _glowAnimation.value * 30,
                            spreadRadius: _glowAnimation.value * 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Bouton principal
                Container(
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        buttonColor,
                        buttonColor.withOpacity(0.9),
                        buttonColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: buttonColor.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: buttonColor.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: buttonColor.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: AnimatedScale(
                    scale: widget.isLoading ? 0.95 : (_isHovered ? 1.02 : 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null && !widget.isLoading)
                          Icon(
                            widget.icon!,
                            color: Colors.white,
                            size: 24,
                          ),
                        if (widget.icon != null && !widget.isLoading)
                          const SizedBox(width: 10),
                        if (widget.isLoading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        else
                          Text(
                            widget.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              height: 1.2,
                            ),
                          ),
                        if (widget.icon != null && !widget.isLoading)
                          const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
                
                // Effet de glow supplémentaire
                if (_isHovered && !widget.isLoading)
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: buttonColor.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Bouton avec effet de shimmer (pour le scan)
class ScanningButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final bool isScanning;
  final VoidCallback? onPressed;

  const ScanningButton({
    super.key,
    required this.text,
    this.icon,
    this.isScanning = false,
    this.onPressed,
  });

  @override
  State<ScanningButton> createState() => _ScanningButtonState();
}

class _ScanningButtonState extends State<ScanningButton> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );
  }

  @override
  void didUpdateWidget(ScanningButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
        _shimmerController.repeat();
      } else {
        _shimmerController.stop();
        _shimmerController.reset();
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MagicButton(
      text: widget.text,
      icon: widget.icon,
      onPressed: widget.onPressed,
      isLoading: widget.isScanning,
      isPrimary: true,
    );
  }
}
