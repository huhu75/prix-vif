import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/screens/product_detail_screen.dart';
import 'package:prix_vif/services/product_analysis_service.dart';
import 'package:prix_vif/services/scan_repository.dart';

ScannedItem _milk(String id, String name, double price, String store, int day, {String? barcode}) => ScannedItem(
      id: id,
      name: name,
      brand: 'Candia',
      price: price,
      quantity: 1,
      unit: 'L',
      scanDate: DateTime(2026, 11, day),
      barcode: barcode,
      storeName: store,
      categories: const ['Milks'],
    );

void main() {
  late ScanRepository repository;
  late ProductAnalysisService service;

  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  setUp(() async {
    Hive.init(Directory.systemTemp.createTempSync('prix_vif_detail').path);
    repository = ScanRepository();
    await repository.init();
    // Pas de réseau dans les tests : Open Food Facts ne répond jamais
    service = ProductAnalysisService(repository, lookupBarcode: (_) async => null);

    await repository.saveScan(ScanSession(id: 's1', date: DateTime(2026, 11, 1), items: [
      _milk('a', 'Lait', 1.20, 'Carrefour', 1, barcode: 'lait'),
      _milk('b', 'Lait Bio', 1.60, 'Carrefour', 1, barcode: 'bio'),
    ]));
    await repository.saveScan(ScanSession(id: 's2', date: DateTime(2026, 11, 8), items: [
      _milk('c', 'Lait', 1.30, 'Carrefour', 8, barcode: 'lait'),
      _milk('d', 'Lait', 1.10, 'Leclerc', 8, barcode: 'lait'),
    ]));
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
  });

  test('analyse locale : historique, magasins, similaires', () {
    final analysis = service.buildAnalysis('lait', 'Lait');

    expect(analysis.priceHistoryByStore.keys.toSet(), {'Carrefour', 'Leclerc'});
    expect(analysis.priceHistoryByStore['Carrefour']!.pricePoints.map((p) => p.price), [1.20, 1.30]);
    expect(analysis.storeComparison.cheapestStore!.storeName, 'Leclerc');
    expect(analysis.storeComparison.storePrices['Carrefour']!.averagePrice, closeTo(1.25, 0.001));
    expect(analysis.similarProducts!.similarProducts.map((p) => p.productName), contains('Lait Bio'));
  });

  test('sans Open Food Facts, la fiche est reconstituée depuis l\'article enregistré', () async {
    final data = await service.load('lait', 'Lait');
    expect(data.offProduct!.name, 'Lait');
    expect(data.offProduct!.brand, 'Candia');
  });

  testWidgets('la fiche produit affiche ses quatre onglets', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(
        home: ProductDetailScreen(
          repository: repository,
          productId: 'lait',
          productName: 'Lait',
          initialTabIndex: 2,
          analysisService: service,
        ),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    expect(find.text('LAIT'), findsOneWidget);
    for (final tab in ['Fiche', 'Évolution', 'Magasins', 'Similaires']) {
      expect(find.text(tab), findsOneWidget);
    }
    // Onglet Magasins ouvert d'emblée : les deux enseignes sont listées
    expect(find.textContaining('Leclerc'), findsWidgets);

    await tester.tap(find.text('Similaires'));
    await tester.pumpAndSettle();
    expect(find.text('Le moins cher'), findsOneWidget);
  });
}
