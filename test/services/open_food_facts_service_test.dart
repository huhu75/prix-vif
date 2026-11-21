import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prix_vif/services/open_food_facts_service.dart';
import 'package:prix_vif/services/scan_repository.dart';

void main() {
  group('OpenFoodFactsService - Fallback Providers (OPF & OBF)', () {
    late ScanRepository repository;

    setUp(() async {
      Hive.init(Directory.systemTemp.createTempSync('prix_vif_off_test').path);
      repository = ScanRepository();
      await repository.init();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
    });

    test('lookupBarcode: renvoie le produit Open Food Facts si trouvé', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') {
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'code': '3017620422003',
                'product_name_fr': 'Nutella',
                'brands': 'Ferrero',
                'nutriscore_grade': 'e',
                'categories_tags': ['en:spreads'],
              }
            }),
            200,
          );
        }
        return http.Response('{"status": 0}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      final product = await service.lookupBarcode('3017620422003');

      expect(product, isNotNull);
      expect(product!.name, 'Nutella');
      expect(product.brand, 'Ferrero');
      expect(product.nutriscore, 'e');
      expect(product.source, 'Open Food Facts');
    });

    test('lookupBarcode: bascule sur Open Products Facts si OFF ne trouve rien', () async {
      final requestedHosts = <String>[];
      final mockClient = MockClient((request) async {
        requestedHosts.add(request.url.host);

        // OFF ne trouve pas le stylo
        if (request.url.host == 'world.openfoodfacts.org') {
          return http.Response(
            jsonEncode({
              'status': 0,
              'status_verbose': 'product found with a different product type: product',
            }),
            200,
          );
        }

        // OPF trouve le surligneur Stabilo
        if (request.url.host == 'world.openproductsfacts.org') {
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'code': '4006381333672',
                'product_name': 'Stabilo Boss Original',
                'brands': 'Stabilo',
                'categories_tags': ['en:highlighters', 'en:pens'],
              }
            }),
            200,
          );
        }

        return http.Response('{"status": 0}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      final product = await service.lookupBarcode('4006381333672');

      expect(product, isNotNull);
      expect(product!.name, 'Stabilo Boss Original');
      expect(product.brand, 'Stabilo');
      expect(product.nutriscore, isNull);
      expect(product.source, 'Open Products Facts');
      expect(requestedHosts, [
        'world.openfoodfacts.org',
        'world.openproductsfacts.org',
      ]);
    });

    test('lookupBarcode: bascule sur Open Beauty Facts si OFF et OPF échouent', () async {
      final requestedHosts = <String>[];
      final mockClient = MockClient((request) async {
        requestedHosts.add(request.url.host);

        if (request.url.host == 'world.openfoodfacts.org') {
          return http.Response('{"status": 0, "status_verbose": "not found"}', 200);
        }
        if (request.url.host == 'world.openproductsfacts.org') {
          return http.Response('{"status": 0, "status_verbose": "not found"}', 200);
        }
        if (request.url.host == 'world.openbeautyfacts.org') {
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'code': '3600523725458',
                'product_name_fr': 'Shampooing Ultra Doux',
                'brands': 'Garnier',
                'categories_tags': ['fr:shampooings'],
              }
            }),
            200,
          );
        }

        return http.Response('{"status": 0}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      final product = await service.lookupBarcode('3600523725458');

      expect(product, isNotNull);
      expect(product!.name, 'Shampooing Ultra Doux');
      expect(product.brand, 'Garnier');
      expect(product.source, 'Open Beauty Facts');
      expect(requestedHosts, [
        'world.openfoodfacts.org',
        'world.openproductsfacts.org',
        'world.openbeautyfacts.org',
      ]);
    });

    test('lookupBarcode: renvoie null si aucun fournisseur ne trouve le produit', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"status": 0}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      final product = await service.lookupBarcode('0000000000000');

      expect(product, isNull);
    });

    test('lookupBarcode: met en cache le produit trouvé via Open Products Facts', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') {
          return http.Response('{"status": 0}', 200);
        }
        if (request.url.host == 'world.openproductsfacts.org') {
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'code': '1234567890128',
                'product_name': 'Cahier Clairefontaine',
                'brands': 'Clairefontaine',
              }
            }),
            200,
          );
        }
        return http.Response('{"status": 0}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      service.setRepository(repository);

      final product1 = await service.lookupBarcode('1234567890128');
      expect(product1, isNotNull);
      expect(product1!.name, 'Cahier Clairefontaine');
      expect(product1.source, 'Open Products Facts');

      // Deuxième lookup : doit provenir du cache sans appel réseau
      final cachedProduct = await service.lookupBarcode('1234567890128');
      expect(cachedProduct, isNotNull);
      expect(cachedProduct!.name, 'Cahier Clairefontaine');
      expect(cachedProduct.source, 'Cache');
    });

    test('searchByName: renvoie les résultats OFF en priorité', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') {
          return http.Response(
            jsonEncode({
              'products': [
                {
                  'code': '111',
                  'product_name': 'Chocolat Noir',
                  'brands': 'Lindt',
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{"products": []}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      final results = await service.searchByName('chocolat');

      expect(results.length, 1);
      expect(results.first.name, 'Chocolat Noir');
      expect(results.first.source, 'Open Food Facts');
    });

    test('searchByName: bascule sur Open Products Facts si OFF est vide', () async {
      final requestedHosts = <String>[];
      final mockClient = MockClient((request) async {
        requestedHosts.add(request.url.host);

        if (request.url.host == 'world.openfoodfacts.org') {
          return http.Response('{"products": []}', 200);
        }
        if (request.url.host == 'world.openproductsfacts.org') {
          return http.Response(
            jsonEncode({
              'products': [
                {
                  'code': '222',
                  'product_name': 'Stylo 4 couleurs',
                  'brands': 'Bic',
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{"products": []}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      final results = await service.searchByName('stylo bic');

      expect(results.length, 1);
      expect(results.first.name, 'Stylo 4 couleurs');
      expect(results.first.brand, 'Bic');
      expect(results.first.source, 'Open Products Facts');
      expect(requestedHosts, [
        'world.openfoodfacts.org',
        'world.openproductsfacts.org',
      ]);
    });

    test('searchByNameWithTwoPasses: utilise le fallback multi-fournisseurs', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['search_terms'] ?? '';
        // Première passe ("stylo bic promo x2") échoue sur tous
        if (query.contains('promo')) {
          return http.Response('{"products": []}', 200);
        }
        // Deuxième passe nettoyée ("stylo bic") réussit sur OPF
        if (request.url.host == 'world.openproductsfacts.org' && query.contains('stylo')) {
          return http.Response(
            jsonEncode({
              'products': [
                {
                  'code': '333',
                  'product_name': 'Bic Cristal',
                  'brands': 'Bic',
                }
              ]
            }),
            200,
          );
        }
        return http.Response('{"products": []}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      final results = await service.searchByNameWithTwoPasses('stylo bic promo x2');

      expect(results.isNotEmpty, isTrue);
      expect(results.first.name, 'Bic Cristal');
      expect(results.first.source, 'Open Products Facts');
    });

    test('searchProducts: détecte code-barres vs recherche texte', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('3017620422003')) {
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'code': '3017620422003',
                'product_name': 'Nutella',
                'brands': 'Ferrero',
              }
            }),
            200,
          );
        }
        return http.Response('{"status": 0, "products": []}', 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);

      // Code-barres
      final barcodeResults = await service.searchProducts('3017620422003');
      expect(barcodeResults.length, 1);
      expect(barcodeResults.first.barcode, '3017620422003');

      // Chaîne vide
      final emptyResults = await service.searchProducts('   ');
      expect(emptyResults, isEmpty);
    });
  });
}
