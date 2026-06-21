import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service abstrait pour le scan de codes-barres
abstract class BarcodeScannerService {
  Widget buildScanner({
    required Function(BarcodeCapture) onDetect,
    required BuildContext context,
  });
  
  Future<void> start();
  Future<void> stop();
  Future<void> toggleTorch();
  bool get isTorchEnabled;
}

/// Implementation par défaut (placeholder pour le web ou si mobile_scanner n'est pas disponible)
class DefaultBarcodeScannerService implements BarcodeScannerService {
  bool _isTorchEnabled = false;
  
  @override
  Widget buildScanner({required Function(BarcodeCapture) onDetect, required BuildContext context}) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 48, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              kIsWeb
                  ? 'La caméra n\'est pas disponible sur le web'
                  : 'mobile_scanner non installé',
              style: TextStyle(color: Colors.white54, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (kIsWeb)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Utilisez l\'application sur mobile',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  @override
  Future<void> start() async {}
  
  @override
  Future<void> stop() async {}
  
  @override
  Future<void> toggleTorch() async {
    _isTorchEnabled = !_isTorchEnabled;
  }
  
  @override
  bool get isTorchEnabled => _isTorchEnabled;
}

/// Factory pour créer le bon service selon la plateforme
/// Si mobile_scanner est disponible et que nous ne sommes pas sur le web,
/// retourne une implémentation avec la vraie caméra
BarcodeScannerService createBarcodeScannerService() {
  // Sur le web, on retourne toujours le service par défaut
  if (kIsWeb) {
    return DefaultBarcodeScannerService();
  }
  
  // Sur mobile, on essaie d'utiliser mobile_scanner si disponible
  // Pour cela, il faut ajouter mobile_scanner: ^5.0.0 dans pubspec.yaml
  try {
    // Nous ne pouvons pas importer mobile_scanner ici car ça causerait
    // des erreurs de compilation sur le web.
    // L'implémentation doit être faite dans un fichier séparé qui n'est
    // importé que sur mobile.
    // Voir mobile_barcode_scanner.dart (à créer quand mobile_scanner est ajouté)
    return DefaultBarcodeScannerService();
  } catch (e) {
    return DefaultBarcodeScannerService();
  }
}

/// Classe de capture de code-barres (pour compatibilité d'API)
class BarcodeCapture {
  final List<Barcode> barcodes;
  
  BarcodeCapture(this.barcodes);
}

/// Classe Barcode (simplifiée)
class Barcode {
  final String? rawValue;
  final String? displayValue;
  final String? format;
  
  Barcode({this.rawValue, this.displayValue, this.format});
}
