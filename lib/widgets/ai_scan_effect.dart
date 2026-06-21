import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';

// Effet de scan IA - Particules intelligentes
class AIScanEffect extends StatefulWidget {
  final bool isActive;
  final double width;
  final double height;

  const AIScanEffect({
    super.key,
    required this.isActive,
    required this.width,
    required this.height,
  });

  @override
  State<AIScanEffect> createState() => _AIScanEffectState();
}

class _AIScanEffectState extends State<AIScanEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Créer des particules
    for (int i = 0; i < 15; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 4 + _random.nextDouble() * 6,
        speed: 0.003 + _random.nextDouble() * 0.007,
        direction: _random.nextDouble() * 2 * math.pi,
        color: AppTheme.primary.withOpacity(0.6 + _random.nextDouble() * 0.4),
      ));
    }

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AIScanEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Animation de vague lumineuse
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: CustomPaint(
                  painter: _WavePainter(
                    progress: _controller.value,
                    color: AppTheme.primary.withOpacity(0.2),
                  ),
                ),
              ),
            ),
            
            // Particules
            ..._particles.map((particle) {
              final progress = _controller.value;
              final x = particle.x + math.cos(particle.direction) * particle.speed * progress;
              final y = particle.y + math.sin(particle.direction) * particle.speed * progress;
              
              // Rebondir sur les bords
              final bounceX = x < 0 ? 1 - x : (x > 1 ? 1 - (x - 1) : x);
              final bounceY = y < 0 ? 1 - y : (y > 1 ? 1 - (y - 1) : y);
              
              // Pulsation subtile
              final scale = 0.5 + 0.5 * (0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi * particle.speed * 10));
              
              return Positioned(
                left: bounceX * widget.width,
                top: bounceY * widget.height,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: BoxDecoration(
                      color: particle.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: particle.color,
                          blurRadius: particle.size * 2,
                          spreadRadius: particle.size,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            
            // Cercle central pulsant
            Positioned.fill(
              child: Center(
                child: Container(
                  width: widget.width * 0.15,
                  height: widget.width * 0.15,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.4),
                        AppTheme.primary.withOpacity(0.05),
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: widget.width * 0.08,
                      height: widget.width * 0.08,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary,
                            blurRadius: 15,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Peintre de vague pour l'effet IA
class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 1.1;
    
    // Dessiner plusieurs cercles avec opacité décroissante
    for (int i = 0; i < 3; i++) {
      final currentProgress = (progress + i * 0.33) % 1.0;
      final currentRadius = radius * (0.7 + i * 0.1);
      
      final path = Path();
      path.addOval(Rect.fromCircle(
        center: center,
        radius: currentRadius,
      ));
      
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.15 - i * 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 - i * 0.5,
      );
      
      // Point lumineux qui tourne
      final angle = currentProgress * 2 * math.pi;
      final pointX = center.dx + currentRadius * math.cos(angle);
      final pointY = center.dy + currentRadius * math.sin(angle);
      
      canvas.drawCircle(
        Offset(pointX, pointY),
        4 - i * 1.0,
        Paint()
          ..color = color.withOpacity(0.8)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// Particule pour l'effet IA
class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double direction;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.direction,
    required this.color,
  });
}

// Animation de fond IA pour tout l'écran
class AIBackgroundEffect extends StatefulWidget {
  final Widget child;
  final bool isActive;

  const AIBackgroundEffect({
    super.key,
    required this.child,
    this.isActive = true,
  });

  @override
  State<AIBackgroundEffect> createState() => _AIBackgroundEffectState();
}

class _AIBackgroundEffectState extends State<AIBackgroundEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(AIBackgroundEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      AppTheme.primary.withOpacity(0.05 * _pulseAnimation.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}

// Random helper
class Random {
  final math.Random _random = math.Random();

  double nextDouble() {
    return _random.nextDouble();
  }
}
