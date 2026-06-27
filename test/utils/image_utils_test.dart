import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:prix_vif/utils/image_utils.dart';

void main() {
  group('ImageUtils', () {
    group('prepareImageForMistral', () {
      late String tempDir;

      setUp(() {
        tempDir = '/tmp/test_images';
        // Créer le dossier temporaire si nécessaire
        Directory(tempDir).createSync(recursive: true);
      });

      tearDown(() {
        // Nettoyer les fichiers temporaires
        try {
          Directory(tempDir).deleteSync(recursive: true);
        } catch (_) {}
      });

      /// Crée un XFile temporaire à partir d'une image en mémoire
      Future<XFile> createTestXFile(img.Image image, String name) async {
        final bytes = img.encodePng(image);
        final file = File('$tempDir/$name.png');
        await file.writeAsBytes(bytes);
        return XFile(file.path);
      }

      test('devrait réussir avec une image valide > 1024px', () async {
        // Créer une image de test de 2000x1000px (rouge)
        final image = img.Image(width: 2000, height: 1000);
        img.fill(image, color: img.ColorRgb8(255, 0, 0));

        final xfile = await createTestXFile(image, 'large_image');
        final result = await prepareImageForMistral(xfile);

        expect(result.success, isTrue);
        expect(result.base64, isNotNull);
        expect(result.base64!.isNotEmpty, isTrue);
        expect(result.originalSize, greaterThan(0));
        expect(result.compressedSize, greaterThan(0));
        expect(result.compressedSize!, lessThan(result.originalSize!));
        expect(result.reductionPercent, greaterThan(0));
        expect(result.error, isNull);
      });

      test('devrait réussir avec une image valide < 1024px', () async {
        // Créer une image de test de 500x500px (verte)
        final image = img.Image(width: 500, height: 500);
        img.fill(image, color: img.ColorRgb8(0, 255, 0));

        final xfile = await createTestXFile(image, 'small_image');
        final result = await prepareImageForMistral(xfile);

        expect(result.success, isTrue);
        expect(result.base64, isNotNull);
        expect(result.originalSize, greaterThan(0));
        expect(result.compressedSize, greaterThan(0));
        // Pour une petite image, la compression peut ne pas réduire autant
        // mais elle ne doit pas augmenter la taille
        expect(result.compressedSize!, lessThanOrEqualTo(result.originalSize!));
        expect(result.error, isNull);
      });

      test('devrait réduire la taille de ≥ 60% pour une grande image', () async {
        // Créer une image de test de 2000x2000px (bleue) - assez grande pour tester la réduction
        final image = img.Image(width: 2000, height: 2000);
        img.fill(image, color: img.ColorRgb8(0, 0, 255));

        final xfile = await createTestXFile(image, 'very_large_image');
        final result = await prepareImageForMistral(xfile);

        expect(result.success, isTrue);
        expect(result.reductionPercent, greaterThanOrEqualTo(60));
      });

      test('devrait échouer avec un fichier vide', () async {
        // Créer un fichier vide
        final file = File('$tempDir/empty.png');
        await file.writeAsBytes([]);
        final xfile = XFile(file.path);

        final result = await prepareImageForMistral(xfile);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.error!.contains('vide'), isTrue);
        expect(result.base64, isNull);
      });

      test('devrait échouer avec un fichier corrompu', () async {
        // Créer un fichier avec des données corrompues
        final file = File('$tempDir/corrupted.png');
        await file.writeAsBytes([0, 1, 2, 3, 4, 5]); // Données non valides
        final xfile = XFile(file.path);

        final result = await prepareImageForMistral(xfile);

        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        expect(result.base64, isNull);
      });

      test('devrait retourner le bon format de résultat en cas de succès', () async {
        final image = img.Image(width: 1000, height: 1000);
        img.fill(image, color: img.ColorRgb8(128, 128, 128));

        final xfile = await createTestXFile(image, 'format_test');
        final result = await prepareImageForMistral(xfile);

        expect(result.success, isTrue);
        expect(result.base64, isA<String>());
        expect(result.originalSize, isA<int>());
        expect(result.compressedSize, isA<int>());
        expect(result.reductionPercent, isA<double>());
        expect(result.error, isNull);
      });

      test('devrait retourner le bon format de résultat en cas d\'échec', () async {
        final file = File('$tempDir/invalid.png');
        await file.writeAsBytes([255, 255, 255]); // Données invalides
        final xfile = XFile(file.path);

        final result = await prepareImageForMistral(xfile);

        expect(result.success, isFalse);
        expect(result.base64, isNull);
        expect(result.originalSize, isNull);
        expect(result.compressedSize, isNull);
        expect(result.reductionPercent, isNull);
        expect(result.error, isA<String>());
      });
    });

    group('formatFileSize', () {
      test('devrait formater les octets', () {
        expect(formatFileSize(500), '500 o');
      });

      test('devrait formater les Ko', () {
        expect(formatFileSize(1024), '1.00 Ko');
        expect(formatFileSize(1536), '1.50 Ko');
      });

      test('devrait formater les Mo', () {
        expect(formatFileSize(1024 * 1024), '1.00 Mo');
        expect(formatFileSize(1024 * 1024 * 2), '2.00 Mo');
      });
    });

    group('getCompressionMessage', () {
      test('devrait retourner un message vide si échec', () {
        final result = ImagePreparationResult(
          success: false,
          error: 'Test error',
        );
        expect(getCompressionMessage(result), '');
      });

      test('devrait retourner un message vide si données manquantes', () {
        final result = ImagePreparationResult(
          success: true,
          base64: 'test',
          // originalSize et compressedSize sont null
        );
        expect(getCompressionMessage(result), '');
      });

      test('devrait formater le message de compression', () {
        final result = ImagePreparationResult(
          success: true,
          base64: 'test',
          originalSize: 2048,
          compressedSize: 819,
          reductionPercent: 60.0,
        );
        final message = getCompressionMessage(result);
        expect(message.contains('2.00 Ko'), isTrue);
        expect(message.contains('0.80 Ko'), isTrue);
        expect(message.contains('60.0%'), isTrue);
      });
    });
  });
}
