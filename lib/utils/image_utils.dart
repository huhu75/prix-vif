import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

/// Résultat de la préparation d'une image pour Mistral AI.
class ImagePreparationResult {
  final bool success;
  final String? base64;
  final int? originalSize; // en octets
  final int? compressedSize;
  final double? reductionPercent;
  final String? error;

  const ImagePreparationResult({
    required this.success,
    this.base64,
    this.originalSize,
    this.compressedSize,
    this.reductionPercent,
    this.error,
  });
}

/// Prépare une image pour l'envoi à Mistral AI.
/// 
/// Étapes effectuées :
/// 1. Lecture et décodage de l'image
/// 2. Redimensionnement à 1024px de large maximum (conservation du ratio)
/// 3. Compression JPEG à 80% de qualité
/// 4. Encodage en base64
/// 
/// Retourne un [ImagePreparationResult] avec :
/// - En cas de succès : base64, tailles originales/compressées, pourcentage de réduction
/// - En cas d'échec : message d'erreur
/// 
/// **Critère de validation** : la réduction doit être ≥ 60% (sinon un warning est logué)
Future<ImagePreparationResult> prepareImageForMistral(XFile imageFile) async {
  try {
    // 1. Lire les bytes de l'image
    final bytes = await imageFile.readAsBytes();
    final originalSize = bytes.length;

    if (originalSize == 0) {
      return const ImagePreparationResult(
        success: false,
        error: "Le fichier image est vide",
      );
    }

    // 2. Décoder l'image
    final image = img.decodeImage(bytes);
    if (image == null) {
      return const ImagePreparationResult(
        success: false,
        error: "Échec de décodage de l'image : format non supporté ou fichier corrompu",
      );
    }

    // 3. Redimensionner si nécessaire (max 1024px de large)
    final resizedImage = (image.width > 1024)
        ? img.copyResize(image, width: 1024)
        : image;

    // 4. Compresser en JPEG à 80% de qualité
    final compressedBytes = img.encodeJpg(resizedImage, quality: 80);
    final compressedSize = compressedBytes.length;

    // 5. Calculer le pourcentage de réduction
    final reductionPercent = originalSize > 0
        ? ((originalSize - compressedSize) / originalSize) * 100
        : 0.0;

    // 6. Vérifier le critère de réduction (≥ 60%)
    if (reductionPercent < 60) {
      debugPrint(
        "⚠️ [ImageUtils] Réduction insuffisante : ${reductionPercent.toStringAsFixed(1)}% "
        "(objectif : ≥ 60%). Taille originale : ${(originalSize / 1024).toStringAsFixed(2)} Ko, "
        "compressée : ${(compressedSize / 1024).toStringAsFixed(2)} Ko"
      );
    }

    // 7. Encoder en base64
    final base64 = base64Encode(compressedBytes);

    return ImagePreparationResult(
      success: true,
      base64: base64,
      originalSize: originalSize,
      compressedSize: compressedSize,
      reductionPercent: reductionPercent,
    );
  } on IOException catch (e) {
    return ImagePreparationResult(
      success: false,
      error: "Erreur de lecture du fichier : $e",
    );
  } on FormatException catch (e) {
    return ImagePreparationResult(
      success: false,
      error: "Format d'image invalide : $e",
    );
  } catch (e) {
    // Capture OutOfMemory et autres exceptions
    final errorMessage = e.toString().toLowerCase().contains('out of memory')
        ? "Mémoire insuffisante pour traiter cette image"
        : "Erreur inconnue lors de la préparation de l'image : $e";
    return ImagePreparationResult(
      success: false,
      error: errorMessage,
    );
  }
}

/// Formate une taille en octets en une chaîne lisible (Ko, Mo).
String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return "$bytes o";
  } else if (bytes < 1024 * 1024) {
    return "${(bytes / 1024).toStringAsFixed(2)} Ko";
  } else {
    return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} Mo";
  }
}

/// Génère un message utilisateur pour afficher les métriques de compression.
/// Exemple : "Image compressée de 2.50 Ko → 0.85 Ko (réduction de 66.0%)"
String getCompressionMessage(ImagePreparationResult result) {
  if (!result.success || result.originalSize == null || result.compressedSize == null) {
    return "";
  }

  final original = formatFileSize(result.originalSize!);
  final compressed = formatFileSize(result.compressedSize!);
  final reduction = result.reductionPercent!.toStringAsFixed(1);

  return "Image compressée de $original → $compressed (réduction de $reduction%)";
}
