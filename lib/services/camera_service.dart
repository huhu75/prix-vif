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
  Future<void>? _initializationFuture;

  MobileScannerController get controller => _controller!;
  bool get isTorchEnabled => _isTorchEnabled;
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;

  CameraService();

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
      
      // Clean up the failed controller
      _controller?.dispose();
      
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
        _controller?.dispose();
        _controller = null;
      }
    }
  }

  Future<void> start() async {
    // Si déjà initialisé, on s'assure qu'il tourne
    if (_isInitialized && _controller != null) {
      if (!_controller!.value.isRunning) {
        await _controller!.start();
      }
      _isScanning = true;
      return;
    }

    // Si une initialisation est déjà en cours, on attend sa fin
    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    // Sinon, on lance l'initialisation
    _initializationFuture = _initializeController();
    await _initializationFuture;
    _initializationFuture = null;
  }

  Future<void> stop() async {
    if (_controller != null) {
      await _controller!.stop();
      _isScanning = false;
      _isTorchEnabled = false;
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
      _controller = null;
      _isInitialized = false;
      _isScanning = false;
    }
  }
}
