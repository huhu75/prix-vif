import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/main.dart';
import 'package:prix_vif/screens/home_screen.dart';
import 'package:prix_vif/theme.dart';
import 'package:prix_vif/widgets/scan/scan_mode_selector.dart';

import '../helpers/app_test_helpers.dart';

bool _scannerInBarcodeMode(WidgetTester tester) =>
    tester.widget<ScanModeSelector>(find.byType(ScanModeSelector)).isBarcodeMode;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('HomeScreen', () {
    testWidgets('affiche les 3 actions et appelle le bon callback', (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: HomeScreen(
          onScanBarcode: () => calls.add('barcode'),
          onScanTicket: () => calls.add('ticket'),
          onOpenAnalysis: () => calls.add('analysis'),
        ),
      ));

      expect(find.text('Scanner un code-barres'), findsOneWidget);
      expect(find.text('Scanner un ticket de caisse'), findsOneWidget);
      expect(find.text('Analyser les produits et magasins'), findsOneWidget);

      for (final key in ['home_scan_barcode', 'home_scan_ticket', 'home_analysis']) {
        // L'écran de test (800×600) est plus petit qu'un téléphone : faire défiler
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey(key)));
      }
      expect(calls, ['barcode', 'ticket', 'analysis']);
    });
  });

  group('Navigation depuis l\'accueil', () {
    setUpAll(() {
      Hive.init(Directory.systemTemp.createTempSync('prix_vif_home_test').path);
    });

    setUp(() {
      mockPluginChannels();
      useTallTestScreen();
    });

    tearDown(resetTestScreen);

    testWidgets('l\'app s\'ouvre sur l\'accueil, pas sur le scanner', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      expect(visibleTab(tester), 0);
      expect(find.text('Que veux-tu faire ?'), findsOneWidget);
      expect(find.text('Accueil'), findsOneWidget); // onglet de la barre du bas
    });

    testWidgets('les cartes de scan ouvrent le Scanner dans le bon mode', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home_scan_ticket')));
      await settle(tester);
      expect(visibleTab(tester), 1);
      expect(_scannerInBarcodeMode(tester), isFalse);

      // Retour à l'accueil par la barre du bas, puis code-barres
      await tester.tap(find.text('Accueil'));
      await settle(tester);
      expect(visibleTab(tester), 0);

      await tester.tap(find.byKey(const ValueKey('home_scan_barcode')));
      await settle(tester);
      expect(visibleTab(tester), 1);
      expect(_scannerInBarcodeMode(tester), isTrue);
    });

    testWidgets('la carte d\'analyse ouvre le tableau de bord', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home_analysis')));
      await settle(tester);

      expect(visibleTab(tester), 3);
    });
  });
}
