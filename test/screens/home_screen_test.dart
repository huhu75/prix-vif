import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/main.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/screens/home_screen.dart';
import 'package:prix_vif/screens/scan_screen.dart';
import 'package:prix_vif/theme.dart';
import 'package:prix_vif/widgets/scan/scan_mode_selector.dart';

import '../helpers/app_test_helpers.dart';

bool _scannerInBarcodeMode(WidgetTester tester) =>
    tester.widget<ScanModeSelector>(find.byType(ScanModeSelector)).isBarcodeMode;

ScannedItem _item(String id, String name, double price, String store, DateTime date) => ScannedItem(
      id: id,
      name: name,
      brand: 'Marque',
      price: price,
      scanDate: date,
      barcode: name.toLowerCase(),
      storeName: store,
    );

/// Lait : 1.00 € puis 1.20 € chez Carrefour, 0.99 € chez Leclerc ; Beurre chez Carrefour
List<ScanSession> _sessions() {
  final now = DateTime(2026, 11, 20);
  final before = DateTime(2026, 11, 10);
  return [
    ScanSession(id: 'avant', date: before, items: [
      _item('1', 'Lait', 1.00, 'Carrefour', before),
      _item('2', 'Beurre', 3.00, 'Carrefour', before),
    ]),
    ScanSession(id: 'carrefour', date: now, items: [
      _item('3', 'Lait', 1.20, 'Carrefour', now),
      _item('4', 'Beurre', 3.00, 'Carrefour', now.subtract(const Duration(hours: 1))),
    ]),
    ScanSession(id: 'leclerc', date: now, items: [_item('5', 'Lait', 0.99, 'Leclerc', before)]),
  ];
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('HomeScreen', () {
    late List<String> calls;
    late List<(String, int)> opened;

    Future<void> pumpHome(WidgetTester tester, List<ScanSession> sessions) async {
      calls = [];
      opened = [];
      useTallTestScreen();
      addTearDown(resetTestScreen);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: HomeScreen(
          sessions: sessions,
          onScanBarcode: () => calls.add('barcode'),
          onScanTicket: () => calls.add('ticket'),
          onSearch: () => calls.add('search'),
          onSeeProducts: () => calls.add('products'),
          onSeeIncreases: () => calls.add('increases'),
          onProductTap: (id, _, {initialTabIndex = 0}) => opened.add((id, initialTabIndex)),
        ),
      ));
      await settle(tester);
    }

    testWidgets('rien de scanné : recherche et invitation au premier scan', (tester) async {
      await pumpHome(tester, const []);

      expect(find.text('PRIX VIF'), findsWidgets);
      expect(find.text('Scanne ton premier produit'), findsOneWidget);
      for (final key in ['home_search', 'home_scan_barcode', 'home_scan_ticket']) {
        await tester.tap(find.byKey(ValueKey(key)));
      }
      expect(calls, ['search', 'barcode', 'ticket']);
      // Sans scan : ni panier, ni derniers scans, ni hausses
      expect(find.text('Tes derniers scans'), findsNothing);
      expect(find.text('Ce qui a augmenté'), findsNothing);
    });

    testWidgets('panier, derniers scans et hausses, qui ouvrent la fiche du produit', (tester) async {
      await pumpHome(tester, _sessions());

      // Le bouton Scanner de la barre du bas suffit : pas de tuiles en double
      expect(find.byKey(const ValueKey('home_first_scan')), findsNothing);
      expect(find.text('Ton panier est moins cher chez'), findsOneWidget);

      // Où économiser : Lait à 0,99 € chez Leclerc au lieu de 1,20 € chez Carrefour
      expect(find.text('Où économiser'), findsOneWidget);
      expect(find.text('0,99 € chez Leclerc au lieu de 1,20 € chez Carrefour'), findsOneWidget);
      expect(find.text('-0,21 €'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home_saving_lait')));
      expect(opened.last, ('lait', 2));
      expect(find.text('Tes derniers scans'), findsOneWidget);
      // Lait à 1.20 chez Carrefour, vu à 0.99 chez Leclerc
      expect(find.text('+0,21 €'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('home_recent_lait')));
      expect(opened.last, ('lait', 2), reason: 'fiche sur l\'onglet Magasins');

      expect(find.text('Ce qui a augmenté'), findsOneWidget);
      await tester.ensureVisible(find.text('+0,20 €'));
      await tester.pump();
      await tester.tap(find.text('+0,20 €'));
      expect(opened.last, ('lait', 1), reason: 'fiche sur l\'onglet Évolution');
    });
  });

  group('Depuis l\'accueil de l\'app', () {
    setUpAll(() {
      Hive.init(Directory.systemTemp.createTempSync('prix_vif_home_test').path);
    });

    setUp(() {
      mockPluginChannels();
      useTallTestScreen();
    });

    tearDown(resetTestScreen);

    testWidgets('l\'app s\'ouvre sur l\'accueil', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      expect(visibleTab(tester), 0);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('les tuiles ouvrent le scanner dans le bon mode', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home_scan_ticket')));
      await settle(tester);
      await settle(tester);
      expect(find.byType(ScanScreen), findsOneWidget);
      expect(_scannerInBarcodeMode(tester), isFalse);

      await tester.tap(find.byKey(const ValueKey('nav_back')).hitTestable());
      await settle(tester);
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home_scan_barcode')));
      await settle(tester);
      await settle(tester);
      expect(_scannerInBarcodeMode(tester), isTrue);
    });

    testWidgets('la recherche ouvre l\'onglet Produits', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home_search')));
      await settle(tester);
      expect(visibleTab(tester), 1);
    });
  });
}
