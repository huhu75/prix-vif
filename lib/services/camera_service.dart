import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Service pour gérer la caméra et le scan de codes-barres
class CameraService {
  MobileScannerController? _controller;
  bool _isTorchEnabled = false;
  bool _isScanning = false;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  MobileScannerController get controller => _controller!;
  bool get isTorchEnabled => _isTorchEnabled;
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  CameraService() {
    _initializeController();
  }

  Future<void> _initializeController() async {
    try {
      _controller = MobileScannerController(
        autoStart: false,
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      await _controller!.start();
      _isInitialized = true;
      _isScanning = true;
      _hasError = false;
      _errorMessage = null;
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Erreur initialisation: ${e.toString()}';
      _isInitialized = false;
      // Essayer avec la caméra avant
      try {
        _controller = MobileScannerController(
          autoStart: false,
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.front,
          torchEnabled: false,
        );
        await _controller!.start();
        _isInitialized = true;
        _isScanning = true;
        _hasError = false;
        _errorMessage = null;
      } catch (e2) {
        _hasError = true;
        _errorMessage = 'Aucune caméra disponible: ${e2.toString()}';
        _isInitialized = false;
      }
    }
  }

  Future<void> start() async {
    if (_controller == null || !_isInitialized) {
      await _initializeController();
    } else if (!_controller!.value.isInitialized) {
      await _controller!.start();
      _isScanning = true;
    }
  }

  Future<void> stop() async {
    if (_controller != null) {
      await _controller!.stop();
      _isScanning = false;
    }
  }

  Future<void> toggleTorch() async {
    if (_controller != null) {
      _isTorchEnabled = !_isTorchEnabled;
      await _controller!.toggleTorch();
    }
  }

  Widget buildCameraPreview({
    required Function(List<Barcode>) onDetect,
    required BuildContext context,
  }) {
    // Si le contrôleur n'est pas initialisé, afficher un message d'erreur
    if (_controller == null || !_isInitialized || _hasError) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Caméra non disponible',
                style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              const Text(
                'Vérifiez que l\'application a accès à la caméra',
                style: TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Paramètres → Applications → Prix Vif → Permissions',
                style: TextStyle(color: Colors.white38, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return MobileScanner(
      controller: _controller!,
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
                  'Erreur caméra',
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
    if (_controller != null) {
      _controller!.dispose();
    }
  }
}
