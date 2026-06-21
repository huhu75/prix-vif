# Configuration de la caméra pour Prix Vif

## Activer la caméra sur mobile

Par défaut, l'application utilise un placeholder pour la caméra qui fonctionne sur toutes les plateformes.

Pour activer la **vraie caméra** sur Android et iOS :

### 1. Ajouter la dépendance mobile_scanner

Dans `pubspec.yaml`, décommentez la ligne suivante sous `dependencies` :

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... autres dépendances ...
  mobile_scanner: ^5.0.0
```

Puis exécutez :
```bash
flutter pub get
```

### 2. Implémenter MobileBarcodeScannerService

Créez un fichier `lib/services/mobile_barcode_scanner.dart` avec le contenu suivant :

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'barcode_scanner.dart';

/// Implémentation avec mobile_scanner pour Android/iOS
class MobileBarcodeScannerService implements BarcodeScannerService {
  final MobileScannerController _controller = MobileScannerController(
    autoStart: false,
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  
  bool _isTorchEnabled = false;
  
  @override
  Widget buildScanner({required Function(BarcodeCapture) onDetect, required BuildContext context}) {
    return MobileScanner(
      controller: _controller,
      onDetect: (BarcodeCapture capture) => onDetect(capture),
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
                Text(
                  'Erreur: ${error.toString()}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  @override
  Future<void> start() async {
    await _controller.start();
  }
  
  @override
  Future<void> stop() async {
    await _controller.stop();
  }
  
  @override
  Future<void> toggleTorch() async {
    _isTorchEnabled = !_isTorchEnabled;
    await _controller.toggleTorch();
  }
  
  @override
  bool get isTorchEnabled => _isTorchEnabled;
}
```

### 3. Mettre à jour la factory

Dans `lib/services/barcode_scanner.dart`, modifiez la fonction `createBarcodeScannerService()` :

```dart
BarcodeScannerService createBarcodeScannerService() {
  if (kIsWeb) {
    return DefaultBarcodeScannerService();
  }
  
  // Retourner l'implémentation mobile
  return MobileBarcodeScannerService();
}
```

### 4. Ajouter les permissions Android

Dans `android/app/src/main/AndroidManifest.xml`, assurez-vous que ces permissions sont présentes :

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.FLASHLIGHT" />
    <uses-feature android:name="android.hardware.camera" />
    <uses-feature android:name="android.hardware.camera.autofocus" />
    
    <application ...>
        ...
    </application>
</manifest>
```

### 5. Ajouter les permissions iOS

Dans `ios/Runner/Info.plist`, ajoutez :

```xml
<key>NSCameraUsageDescription</key>
<string>Cette application a besoin d'accéder à la caméra pour scanner les codes-barres, tickets de caisse et étiquettes de prix.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Cette application pourrait avoir besoin d'accéder au microphone pour certaines fonctionnalités de scan.</string>
```

## Build et test

### Pour le web :
```bash
flutter build web
flutter run -d chrome
```

### Pour Android :
```bash
flutter run -d android
```

### Pour iOS :
```bash
flutter run -d ios
```

## Notes

- Le web affichera toujours un placeholder car mobile_scanner n'est pas compatible avec le web
- Sur mobile, la caméra sera fonctionnelle une fois mobile_scanner ajouté
- Le flash, le changement de caméra avant/arrière sont gérés automatiquement
