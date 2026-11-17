import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/services/scan_repository.dart';

ScannedItem _item(String id, {String name = 'Lait', String? store = 'Carrefour', double price = 1.5}) {
  return ScannedItem(
    id: id,
    name: name,
    brand: 'Candia',
    price: price,
    scanDate: DateTime(2026, 11, 17),
    barcode: 'ean_$name',
    storeName: store,
  );
}

ScanSession _session(String id, List<ScannedItem> items, {String type = 'barcode'}) {
  return ScanSession(
    id: id,
    items: items,
    date: DateTime(2026, 11, 17),
    storeName: items.first.storeName,
    type: type,
  );
}

void main() {
  late ScanRepository repository;

  setUp(() async {
    Hive.init(Directory.systemTemp.createTempSync('prix_vif_test').path);
    repository = ScanRepository();
    await repository.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  group('saveScan', () {
    test('regrouper des scans déjà sauvegardés ne laisse pas de sessions vides', () async {
      // Sauvegarde automatique : une session par article scanné
      final a = _item('a');
      final b = _item('b', name: 'Pain');
      await repository.saveScan(_session('auto_a', [a]));
      await repository.saveScan(_session('auto_b', [b]));

      // Bouton « Enregistrer » : une session regroupant les mêmes articles
      await repository.saveScan(_session('manual', [a, b]));

      final sessions = await repository.getAllScans();
      expect(sessions.map((s) => s.id), ['manual']);
      expect(sessions.single.items.length, 2);
    });

    test('une session dont il reste des articles est conservée', () async {
      final a = _item('a');
      final b = _item('b', name: 'Pain');
      await repository.saveScan(_session('ticket', [a, b], type: 'ticket'));

      await repository.saveScan(_session('manual', [a]));

      final sessions = await repository.getAllScans();
      expect(sessions.map((s) => s.id).toSet(), {'ticket', 'manual'});
    });

    test('init supprime les sessions vides laissées par les anciennes versions', () async {
      await repository.saveScan(_session('pleine', [_item('a')]));
      await Hive.box<Map>('scans').put('vide', {
        'id': 'vide',
        'date': DateTime(2026, 11, 1).toIso8601String(),
        'endDate': null,
        'type': 'barcode',
        'storeName': 'Leclerc',
        'totalAmount': 2.0,
      });

      final reopened = ScanRepository();
      await reopened.init();

      final sessions = await reopened.getAllScans();
      expect(sessions.map((s) => s.id), ['pleine']);
    });
  });

  group('données de démo', () {
    test('le drapeau de démo survit à « Tout supprimer »', () async {
      expect(repository.isDemoSeeded, isFalse);

      await repository.markDemoSeeded();
      await repository.clearAllScans();

      expect(repository.isDemoSeeded, isTrue);
      expect(await repository.getAllScans(), isEmpty);
    });
  });

  group('getUniqueProducts', () {
    test('inclut le magasin du premier scan', () async {
      await repository.saveScan(_session('s1', [_item('a', store: 'Carrefour')]));

      final products = repository.getUniqueProducts();
      expect(products.single['stores'], ['Carrefour']);
    });

    test('cumule les magasins de tous les scans', () async {
      await repository.saveScan(_session('s1', [_item('a', store: 'Carrefour')]));
      await repository.saveScan(_session('s2', [_item('b', store: 'Leclerc')]));

      final products = repository.getUniqueProducts();
      expect((products.single['stores'] as List).toSet(), {'Carrefour', 'Leclerc'});
      expect(products.single['scanCount'], 2);
    });
  });
}
