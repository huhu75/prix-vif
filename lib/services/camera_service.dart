import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Service pour gérer la caméra et le scan de codes-barres
class CameraService {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: true,
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isTorchEnabled = false;
  bool _isScanning = false;

  MobileScannerController get controller => _controller;
  bool get isTorchEnabled => _isTorchEnabled;
  bool get isScanning => _isScanning;

  Future<void> start() async {
    // Le contrôleur est déjà en autoStart, donc on vérifie juste qu'il est prêt
    if (!_controller.value.isInitialized) {
      await _controller.start();
    }
    _isScanning = true;
  }

  Future<void> stop() async {
    await _controller.stop();
    _isScanning = false;
  }

  Future<void> toggleTorch() async {
    _isTorchEnabled = !_isTorchEnabled;
    await _controller.toggleTorch();
  }

  Widget buildCameraPreview({
    required Function(List<Barcode>) onDetect,
    required BuildContext context,
  }) {
    return MobileScanner(
      controller: _controller,
      onDetect: (capture) => onDetect(capture.barcodes),
      fit: BoxFit.cover,
      placeholderBuilder: (context, constraints) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off, size: 48, color: Colors.white54),
                SizedBox(height: 16),
                Text(
                  'Initialisation de la caméra...',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Autorisez l\'accès à la caméra dans la popup',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
      errorBuilder: (context, error, child) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Caméra non disponible',
                  style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Erreur: ${error.toString()}',
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Vérifiez les permissions dans les paramètres',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void dispose() {
    _controller.dispose();
  }
}
