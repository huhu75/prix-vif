import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/models/product_category.dart';
import 'package:prix_vif/services/category_service.dart';
import 'package:prix_vif/services/open_food_facts_service.dart';
import 'package:prix_vif/services/scan_repository.dart';

ScannedItem _item(String id, String? barcode, String name) => ScannedItem(
      id: id,
      name: name,
      brand: 'Marque',
      price: 1.50,
      scanDate: DateTime(2026, 11, 10),
      barcode: barcode,
      storeName: 'Leclerc',
    );

const _pomme = '3000000000011';
const _inconnu = '3000000000028';

/// Faux Open Food Facts : [_pomme] est un jus de pomme, [_inconnu] n'existe nulle part
http.Response _fakeOff(http.Request request, List<String> calls) {
  calls.add('${request.url.host}${request.url.path}');
  final path = request.url.path;
  if (path.contains('/taxonomy')) {
    return http.Response(
      jsonEncode({
        'en:apple-juices': {
          'name': {'fr': 'Jus de pomme', 'en': 'Apple juices'},
        },
      }),
      200,
    );
  }
  if (request.url.host == 'world.openfoodfacts.org' && path.endsWith('/$_pomme')) {
    return http.Response(
      jsonEncode({
        'status': 1,
        'product': {'compared_to_category': 'en:apple-juices'},
      }),
      200,
    );
  }
  return http.Response(jsonEncode({'status': 0}), 404);
}

void main() {
  late ScanRepository repository;

  setUp(() async {
    Hive.init(Directory.systemTemp.createTempSync('prix_vif_categories').path);
    repository = ScanRepository();
    await repository.init();
    await repository.saveScan(ScanSession(id: 's', date: DateTime(2026, 11, 10), items: [
      _item('1', _pomme, 'Pur jus de pomme'),
      _item('2', _inconnu, 'Produit inconnu'),
      _item('3', null, 'Ligne de ticket'),
    ]));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('complète les catégories manquantes avec leur nom français', () async {
    final calls = <String>[];
    final service = CategoryService(repository, httpClient: MockClient((r) async => _fakeOff(r, calls)));

    expect(repository.barcodesMissingCategory().toSet(), {_pomme, _inconnu});
    final found = await service.fillMissing();

    expect(found, 1);
    final category = repository.getProductCategory('bc_$_pomme')!;
    expect(category.id, 'en:apple-juices');
    expect(category.label, 'Jus de pomme');
    expect(category.manual, isFalse);
    expect(repository.getCategoryLabel('en:apple-juices'), 'Jus de pomme');

    // Produit absent partout : retenu pour ne pas être redemandé à chaque lancement
    expect(repository.getProductCategory('bc_$_inconnu'), isNull);
    expect(repository.barcodesMissingCategory(), isEmpty);
    // … mais redemandé après le délai de nouvel essai
    expect(
      repository.barcodesMissingCategory(now: DateTime.now().add(ScanRepository.noCategoryRetryDelay * 2)),
      [_inconnu],
    );

    // Deuxième passage : plus rien à chercher
    calls.clear();
    expect(await service.fillMissing(), 0);
    expect(calls, isEmpty);
  });

  test('hors-ligne : rien n\'est enregistré, la recherche reprendra plus tard', () async {
    final service = CategoryService(
      repository,
      httpClient: MockClient((_) async => throw const SocketException('hors-ligne')),
    );
    expect(await service.fillMissing(), 0);
    expect(repository.barcodesMissingCategory().toSet(), {_pomme, _inconnu});
  });

  test('une catégorie choisie à la main n\'est jamais remplacée par Open Food Facts', () async {
    await repository.setProductCategory('bc_$_pomme', ProductCategory.custom('Mes jus'));
    final service = CategoryService(repository, httpClient: MockClient((r) async => _fakeOff(r, [])));

    final product = OFFProduct(
      barcode: _pomme,
      name: 'Pur jus de pomme',
      brand: 'Marque',
      categories: const [],
      allergens: const [],
      nutrientLevels: const {},
      nutriments: const {},
      categoryId: 'en:apple-juices',
    );
    final kept = await service.applyFromProduct(_pomme, product);

    expect(kept!.label, 'Mes jus');
    expect(repository.getProductCategory('bc_$_pomme')!.manual, isTrue);
    // Les catégories connues alimentent le choix à la main
    expect(repository.getKnownCategories().map((c) => c.label), ['Mes jus']);
  });

  test('scan d\'un produit : sa catégorie Open Food Facts est enregistrée tout de suite', () async {
    final service = CategoryService(repository, httpClient: MockClient((r) async => _fakeOff(r, [])));
    final product = OFFProduct(
      barcode: _pomme,
      name: 'Pur jus de pomme',
      brand: 'Marque',
      categories: const [],
      allergens: const [],
      nutrientLevels: const {},
      nutriments: const {},
      categoryId: 'en:apple-juices',
    );
    final category = await service.applyFromProduct(_pomme, product);
    expect(category!.label, 'Jus de pomme');
    expect(repository.getAllProductCategories().keys, ['bc_$_pomme']);
  });
}
