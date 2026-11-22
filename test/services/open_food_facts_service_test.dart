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

  group('OpenFoodFactsService - Libellés de ticket abrégés', () {
    final service = OpenFoodFactsService(httpClient: MockClient((_) async => http.Response('{}', 200)));

    test('cleanProductName: développe les abréviations et retire les contenances', () {
      expect(service.cleanProductName('LESS LIQ MIR COUL 1.35L'), 'lessive liquide mir couleur');
      expect(service.cleanProductName('MIR LESSIVE LIQUIDE COULEUR 1,35L'), 'mir lessive liquide couleur');
      expect(service.cleanProductName('MIR LESS. RAV. NOIR'), 'mir lessive rav noir');
      expect(service.cleanProductName('Coca-Cola 6x33cl'), 'coca cola');
      expect(service.cleanProductName('CHOC NOIR 70%'), 'chocolat noir');
      expect(service.cleanProductName('stylo bic promo x2'), 'stylo bic');
      expect(service.cleanProductName('LAIT 1/2 ECR 1L'), 'lait ecreme');
    });

    /// Client qui ne renvoie un produit que pour la requête [matchingQuery]
    /// et note toutes les requêtes reçues dans [queries].
    MockClient clientMatching(String matchingQuery, List<String> queries) {
      return MockClient((request) async {
        final query = request.url.queryParameters['search_terms'] ?? '';
        queries.add(query);
        if (request.url.host == 'world.openproductsfacts.org' && query == matchingQuery) {
          return http.Response(
            jsonEncode({
              'products': [
                {'code': '3178041363952', 'product_name': 'Mir couleur', 'brands': 'Mir'}
              ]
            }),
            200,
          );
        }
        return http.Response('{"products": []}', 200);
      });
    }

    test('searchByNameWithTwoPasses: libellé abrégé trouvé grâce aux abréviations', () async {
      final queries = <String>[];
      final service = OpenFoodFactsService(
        httpClient: clientMatching('lessive liquide mir couleur', queries),
      );

      final results = await service.searchByNameWithTwoPasses('LESS LIQ MIR COUL 1.35L');

      expect(results.single.name, 'Mir couleur');
      expect(results.single.source, 'Open Products Facts');
      expect(queries.toSet(), {'LESS LIQ MIR COUL 1.35L', 'lessive liquide mir couleur'});
    });

    test('searchByNameWithTwoPasses: 3ème passe avec moins de mots si un mot bloque', () async {
      final queries = <String>[];
      final service = OpenFoodFactsService(httpClient: clientMatching('mir lessive', queries));

      final results = await service.searchByNameWithTwoPasses('MIR LESS. RAV. NOIR');

      expect(results.single.name, 'Mir couleur');
      expect(queries.toSet(), {
        'MIR LESS. RAV. NOIR',
        'mir lessive rav noir',
        'mir lessive rav',
        'mir lessive',
      });
    });

    test('searchByNameWithTwoPasses: 3ème passe limitée à 2 essais et 2 mots minimum', () async {
      final queries = <String>[];
      final service = OpenFoodFactsService(httpClient: clientMatching('introuvable', queries));

      final results = await service.searchByNameWithTwoPasses('aaa bbb ccc ddd eee');

      expect(results, isEmpty);
      expect(queries.toSet(), {'aaa bbb ccc ddd eee', 'aaa bbb ccc ddd', 'aaa bbb ccc'});

      // Deux mots : pas de 3ème passe (un seul mot serait trop vague)
      queries.clear();
      await service.searchByNameWithTwoPasses('aaa bbb');
      expect(queries.toSet(), {'aaa bbb'});
    });
  });

  group('OpenFoodFactsService - Recherche manuelle, cache et surcharge OFF', () {
    late ScanRepository repository;

    setUp(() async {
      Hive.init(Directory.systemTemp.createTempSync('prix_vif_off_manual_test').path);
      repository = ScanRepository();
      await repository.init();
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
    });

    http.Response productsResponse(List<String> names) => http.Response(
          jsonEncode({
            'products': [
              for (var i = 0; i < names.length; i++)
                {'code': '30176204220${i.toString().padLeft(2, '0')}', 'product_name': names[i], 'brands': 'Ferrero'}
            ]
          }),
          200,
        );

    test('searchProducts: réseau d\'abord, tous les résultats même si le nom est en cache', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') {
          return productsResponse(['Nutella 400g', 'Nutella 750g', 'Nutella Biscuits']);
        }
        return http.Response('{"products": []}', 200);
      });
      final service = OpenFoodFactsService(httpClient: mockClient, retryDelays: const [])
        ..setRepository(repository);

      // Le matching du ticket met le premier résultat en cache
      expect((await service.searchByName('Nutella')).length, 3);
      // Matching automatique suivant : le cache suffit (un seul produit)
      final cached = await service.searchByName('nutella');
      expect(cached.single.source, 'Cache');

      // Recherche tapée dans la fiche : tous les résultats du réseau
      final manual = await service.searchProducts('nutella');
      expect(manual.map((p) => p.name), ['Nutella 400g', 'Nutella 750g', 'Nutella Biscuits']);
      expect(manual.first.source, 'Open Food Facts');
    });

    test('searchByName: nouvel essai quand Open Food Facts répond 503', () async {
      var offCalls = 0;
      final mockClient = MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') {
          offCalls++;
          if (offCalls == 1) return http.Response('Service surchargé', 503);
          return productsResponse(['Nutella 400g']);
        }
        return http.Response('{"products": []}', 200);
      });
      final service = OpenFoodFactsService(httpClient: mockClient, retryDelays: const [Duration.zero]);

      final results = await service.searchByName('nutella');

      expect(results.single.name, 'Nutella 400g');
      expect(results.single.source, 'Open Food Facts');
      expect(offCalls, 2);
    });

    test('searchByName: OFF indisponible → résultats de repli non mis en cache', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') return http.Response('Service surchargé', 503);
        if (request.url.host == 'world.openproductsfacts.org') return productsResponse(['Nutella (fiche OPF)']);
        return http.Response('{"products": []}', 200);
      });
      final service = OpenFoodFactsService(httpClient: mockClient, retryDelays: const [Duration.zero])
        ..setRepository(repository);

      final results = await service.searchByName('nutella');

      expect(results.single.source, 'Open Products Facts');
      expect(repository.getCachedProduct('name:nutella'), isNull);
    });

    test('searchProducts: aucun fournisseur ne répond → erreur, ou dernier résultat connu', () async {
      var online = true;
      final mockClient = MockClient((request) async {
        if (!online) return http.Response('Service surchargé', 503);
        if (request.url.host == 'world.openfoodfacts.org') return productsResponse(['Nutella 400g']);
        return http.Response('{"products": []}', 200);
      });
      final service = OpenFoodFactsService(httpClient: mockClient, retryDelays: const [])
        ..setRepository(repository);

      // Rien en cache : erreur (l'écran affiche « recherche impossible », pas « aucun produit »)
      online = false;
      await expectLater(service.searchProducts('nutella'), throwsA(isA<OFFSearchUnavailableException>()));

      // Une recherche réussie met le nom en cache…
      online = true;
      await service.searchByName('nutella');

      // …et sert de repli hors-ligne, sans la clé « name:… » comme code-barres
      online = false;
      final fallback = await service.searchProducts('nutella');
      expect(fallback.single.name, 'Nutella 400g');
      expect(fallback.single.source, 'Cache');
      expect(fallback.single.barcode, isEmpty);
    });

    test('searchProducts: OFF saturé et rien ailleurs → erreur plutôt que « aucun produit »', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'world.openfoodfacts.org') return http.Response('Service surchargé', 503);
        return http.Response('{"products": []}', 200);
      });
      final service = OpenFoodFactsService(httpClient: mockClient, retryDelays: const []);

      await expectLater(service.searchProducts('nutella'), throwsA(isA<OFFSearchUnavailableException>()));
      // Le matching automatique des tickets, lui, ne lève pas d'erreur
      expect(await service.searchByNameWithTwoPasses('nutella'), isEmpty);
    });
  });
}
