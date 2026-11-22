import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/main.dart';
import 'package:prix_vif/theme.dart';
import 'package:prix_vif/widgets/magic_button.dart';
import 'package:prix_vif/widgets/scan/store_selector.dart';

import '../helpers/app_test_helpers.dart';

/// Appels reçus par le plugin caméra (mobile_scanner) pendant le test
final List<String> _cameraCalls = [];

void _recordCameraCalls() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
    (call) async {
      _cameraCalls.add(call.method);
      return null;
    },
  );
}

final _scanButton = find.byKey(const ValueKey('scan_start_button'));

bool _scanButtonEnabled(WidgetTester tester) => tester.widget<MagicButton>(_scanButton).onPressed != null;

/// Bouton Appareil photo / Galerie du mode ticket
bool _ticketButtonEnabled(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ))
    .enabled;

Future<void> _openFromHome(WidgetTester tester, String cardKey) async {
  await tester.tap(find.byKey(ValueKey(cardKey)));
  await settle(tester);
}

Future<void> _chooseStore(WidgetTester tester, String store) async {
  await tester.tap(find.byKey(const ValueKey('store_dropdown')));
  await settle(tester);
  await tester.tap(find.text(store).last);
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('StoreSelector', () {
    testWidgets('propose le dernier magasin en raccourci tant qu\'aucun n\'est choisi', (tester) async {
      String? chosen;
      Widget selector(String? selected) => MaterialApp(
            theme: AppTheme.theme,
            home: Scaffold(
              body: StoreSelector(
                stores: const ['Carrefour', 'Leclerc'],
                selectedStore: selected,
                lastStore: 'Leclerc',
                onSelected: (store) => chosen = store,
                onAdd: () {},
              ),
            ),
          );

      await tester.pumpWidget(selector(null));
      expect(find.text('Choisis ton magasin'), findsOneWidget);
      expect(find.text('Dernier : Leclerc'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('store_last_shortcut')));
      expect(chosen, 'Leclerc');

      // Magasin choisi : plus de raccourci, l'étape est validée
      await tester.pumpWidget(selector('Leclerc'));
      expect(find.text('Dernier : Leclerc'), findsNothing);
      expect(find.text('Magasin'), findsOneWidget);
    });
  });

  group('Scanner : magasin d\'abord, puis SCANNER', () {
    setUpAll(() {
      Hive.init(Directory.systemTemp.createTempSync('prix_vif_scanner_flow_test').path);
    });

    setUp(() {
      mockPluginChannels();
      _cameraCalls.clear();
      _recordCameraCalls();
      useTallTestScreen();
    });

    tearDown(resetTestScreen);

    testWidgets('sans magasin, la caméra ne démarre pas et SCANNER est grisé', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      await _openFromHome(tester, 'home_scan_barcode');

      expect(find.byKey(const ValueKey('scan_idle_no_store')), findsOneWidget);
      expect(_scanButtonEnabled(tester), isFalse);

      await tester.tap(_scanButton);
      await settle(tester);
      expect(_cameraCalls, isEmpty);
    });

    testWidgets('magasin choisi : la caméra attend le tap sur SCANNER', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      await _openFromHome(tester, 'home_scan_barcode');

      await _chooseStore(tester, 'Leclerc');
      expect(find.text('Prêt à scanner chez Leclerc'), findsOneWidget);
      expect(_scanButtonEnabled(tester), isTrue);
      expect(_cameraCalls, isEmpty, reason: 'pas de démarrage automatique');

      await tester.tap(_scanButton);
      await settle(tester);
      expect(_cameraCalls, isNotEmpty, reason: 'SCANNER lance la caméra');
    });

    testWidgets('le magasin reste choisi au retour de Résultats, pas pour une nouvelle séance', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      await _openFromHome(tester, 'home_scan_barcode');
      await _chooseStore(tester, 'Leclerc');

      // Résultats puis Retour : même séance
      await tester.tap(find.text('Résultats').hitTestable().last);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('nav_back')).hitTestable());
      await settle(tester);
      expect(find.text('Prêt à scanner chez Leclerc'), findsOneWidget);

      // Accueil puis carte de scan : nouvelle séance, magasin à rechoisir
      await tester.tap(find.text('Accueil').hitTestable().last);
      await settle(tester);
      await _openFromHome(tester, 'home_scan_barcode');
      expect(find.byKey(const ValueKey('scan_idle_no_store')), findsOneWidget);
      expect(_scanButtonEnabled(tester), isFalse);
    });

    testWidgets('mode ticket : Appareil photo et Galerie attendent le magasin', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      await _openFromHome(tester, 'home_scan_ticket');

      expect(find.byKey(const ValueKey('ticket_no_store')), findsOneWidget);
      expect(_ticketButtonEnabled(tester, 'Appareil photo'), isFalse);
      expect(_ticketButtonEnabled(tester, 'Galerie'), isFalse);

      await _chooseStore(tester, 'Monoprix');
      expect(find.byKey(const ValueKey('ticket_ready')), findsOneWidget);
      expect(_ticketButtonEnabled(tester, 'Appareil photo'), isTrue);
      expect(_ticketButtonEnabled(tester, 'Galerie'), isTrue);
      expect(_cameraCalls, isEmpty, reason: 'le mode ticket n\'utilise pas le scanner');
    });
  });
}
