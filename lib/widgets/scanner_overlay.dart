import 'package:flutter/material.dart';
import '../theme.dart';

// 📷 Overlay du Scanner avec animation moderne 2026
class ScannerOverlay extends StatefulWidget {
  final bool isScanning;
  final String? scannedBarcode;
  final String? errorMessage;
  final VoidCallback onGalleryTap;
  final VoidCallback onFlashToggle;
  final bool isFlashOn;

  const ScannerOverlay({
    super.key,
    this.isScanning = false,
    this.scannedBarcode,
    this.errorMessage,
    required this.onGalleryTap,
    required this.onFlashToggle,
    this.isFlashOn = false,
  });

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );
  }

  @override
  void didUpdateWidget(ScannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
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
    final size = MediaQuery.of(context).size;
    final scannerWidth = size.width * 0.8;
    final scannerHeight = scannerWidth * 0.6;
    
    return Stack(
      children: [
        // Fond semi-transparent
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.6),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        
        // Zone de scan
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Message principal
              const Padding(
                padding: EdgeInsets.only(bottom: 32),
                child: Text(
                  'Scanner un prix',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              
              // Cadre du scanner avec animation
              Stack(
                alignment: Alignment.center,
                children: [
                  // Cadre
                  Container(
                    width: scannerWidth,
                    height: scannerHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.isScanning 
                            ? AppTheme.primary 
                            : AppTheme.textSecondary,
                        width: widget.isScanning ? 3 : 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ),
                  ),
                  
                  // Animation de la ligne de scan
                  if (widget.isScanning)
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        final position = _animation.value;
                        final lineY = scannerHeight * 0.1 + 
                            (scannerHeight * 0.8) * position;
                        
                        return Positioned(
                          top: lineY,
                          left: scannerWidth * 0.1,
                          right: scannerWidth * 0.1,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  
                  // Icône de scan au centre
                  if (!widget.isScanning)
                    const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white54,
                      size: 60,
                    ),
                  
                  // Message "Scanning..."
                  if (widget.isScanning)
                    const Positioned(
                      bottom: 20,
                      child: Text(
                        'Scanning...',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Message d'aide
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                child: Text(
                  'Alignez le code-barres ou le QR code \n dans le cadre pour scanner',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
              
              // Résultat du scan
              if (widget.scannedBarcode != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.backgroundDark,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Code scanné : ${widget.scannedBarcode!}',
                        style: const TextStyle(
                          color: AppTheme.backgroundDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Message d'erreur
              if (widget.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.red.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        
        // Boutons de contrôle en bas
        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Bouton Galerie
              _ControlButton(
                icon: Icons.image,
                label: 'Galerie',
                onTap: widget.onGalleryTap,
              ),
              
              // Bouton Flash
              _ControlButton(
                icon: widget.isFlashOn ? Icons.flash_on : Icons.flash_off,
                label: widget.isFlashOn ? 'Éteindre' : 'Allumer',
                onTap: widget.onFlashToggle,
                isActive: widget.isFlashOn,
              ),
            ],
          ),
        ),
        
        // Coins arrondis pour l'effet "portail"
        Positioned(
          top: 0,
          left: 0,
          child: _CornerDecorator(size: 30, position: CornerPosition.topLeft),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _CornerDecorator(size: 30, position: CornerPosition.topRight),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: _CornerDecorator(size: 30, position: CornerPosition.bottomLeft),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _CornerDecorator(size: 30, position: CornerPosition.bottomRight),
        ),
      ],
    );
  }
}

// 🎛️ Bouton de contrôle
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive 
                  ? AppTheme.primary.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive 
                    ? AppTheme.primary
                    : Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppTheme.primary : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// 🔺 Décorateur de coin
class _CornerDecorator extends StatelessWidget {
  final double size;
  final CornerPosition position;

  const _CornerDecorator({
    required this.size,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: _getBorderRadius(),
      ),
    );
  }

  BorderRadius _getBorderRadius() {
    switch (position) {
      case CornerPosition.topLeft:
        return const BorderRadius.only(
          topLeft: Radius.circular(10),
          bottomRight: Radius.circular(20),
        );
      case CornerPosition.topRight:
        return const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(20),
        );
      case CornerPosition.bottomLeft:
        return const BorderRadius.only(
          bottomLeft: Radius.circular(10),
          topRight: Radius.circular(20),
        );
      case CornerPosition.bottomRight:
        return const BorderRadius.only(
          bottomRight: Radius.circular(10),
          topLeft: Radius.circular(20),
        );
    }
  }
}

enum CornerPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

// 🎯 Indicateur de mise au point
class FocusIndicator extends StatefulWidget {
  const FocusIndicator({super.key});

  @override
  State<FocusIndicator> createState() => _FocusIndicatorState();
}

class _FocusIndicatorState extends State<FocusIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 0.8, end: 0.4).animate(
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
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primary,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
        );
      },
    );
  }
}
