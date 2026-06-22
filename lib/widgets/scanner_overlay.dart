import 'package:flutter/material.dart';
import '../theme.dart';

class ScannerOverlay extends StatefulWidget {
  final bool isScanning;
  final String? scannedBarcode;
  final String? errorMessage;
  final VoidCallback onGalleryTap;
  final VoidCallback? onFlashToggle;
  final bool isFlashOn;
  final Widget? cameraPreview;

  const ScannerOverlay({
    super.key,
    this.isScanning = false,
    this.scannedBarcode,
    this.errorMessage,
    required this.onGalleryTap,
    this.onFlashToggle,
    this.isFlashOn = false,
    this.cameraPreview,
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
    final isLandscape = size.width > size.height;
    final baseSize = isLandscape ? size.height * 0.4 : size.width;
    final scannerWidth = baseSize * 0.8;
    final scannerHeight = scannerWidth * 0.6;
    
    return Stack(
      children: [
        // Preview de la caméra
        if (widget.cameraPreview != null)
          widget.cameraPreview!,
        
        // Overlay avec fond semi-transparent autour de la zone de scan
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            backgroundBlendMode: BlendMode.darken,
          ),
        ),
        
        // Zone de scan
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cadre du scanner avec animation
              Stack(
                alignment: Alignment.center,
                children: [
                  // Cadre transparent avec bordure
                  Container(
                    width: scannerWidth,
                    height: scannerHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.isScanning
                            ? AppTheme.primary
                            : Colors.white.withOpacity(0.3),
                        width: widget.isScanning ? 2 : 1.5,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        color: Colors.transparent,
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
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.3),
                                  blurRadius: 6,
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
                  'Scannez codes-barres, tickets de caisse\n ou étiquettes de prix',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.scannedBarcode!.substring(0, 8),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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
              
              // Bouton Flash (désactivé si callback null)
              if (widget.onFlashToggle != null)
                _ControlButton(
                  icon: widget.isFlashOn ? Icons.flash_on : Icons.flash_off,
                  label: widget.isFlashOn ? 'Éteindre' : 'Allumer',
                  onTap: widget.onFlashToggle!,
                  isActive: widget.isFlashOn,
                )
              else
                Opacity(
                  opacity: 0.5,
                  child: _ControlButton(
                    icon: Icons.flash_off,
                    label: 'Non dispo.',
                    onTap: () {},
                    isActive: false,
                  ),
                ),
            ],
          ),
        ),
        
      ],
    );
  }
}

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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.primary.withOpacity(0.15)
                  : Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppTheme.primary
                    : Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? AppTheme.primary : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
