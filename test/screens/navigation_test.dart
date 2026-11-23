import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/main.dart';
import 'package:prix_vif/screens/history_screen.dart';
import 'package:prix_vif/screens/scan_screen.dart';
import 'package:prix_vif/theme.dart';
import 'package:prix_vif/widgets/nav_buttons.dart';

import '../helpers/app_test_helpers.dart';

/// Bouton Retour de l'écran affiché
final _visibleBack = find.byKey(const ValueKey('nav_back')).hitTestable();

Future<void> _tapTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('nav_tab_$index')));
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('Boutons de navigation', () {
    testWidgets('AppBackButton sans action ferme l\'écran ouvert', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => Scaffold(appBar: AppBar(leading: const AppBackButton()), body: const Text('Page 2')),
              )),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.byTooltip('Retour'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav_back')));
      await tester.pumpAndSettle();
      expect(find.text('Page 2'), findsNothing);
    });
  });

  group('Barre du bas', () {
    setUpAll(() {
      Hive.init(Directory.systemTemp.createTempSync('prix_vif_nav_test').path);
    });

    setUp(() {
      mockPluginChannels();
      useTallTestScreen();
    });

    tearDown(resetTestScreen);

    testWidgets('quatre onglets et le bouton Scanner ; les onglets n\'ont pas de Retour', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      expect(visibleTab(tester), 0);
      for (final label in ['Accueil', 'Produits', 'Ma liste', 'Profil', 'Scanner']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      for (var tab = 0; tab < 4; tab++) {
        await _tapTab(tester, tab);
        expect(visibleTab(tester), tab);
        expect(_visibleBack, findsNothing, reason: 'onglet $tab');
      }
    });

    testWidgets('le bouton Scanner ouvre le scanner depuis n\'importe quel onglet ; Retour le ferme', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      await _tapTab(tester, 2); // Ma liste

      await tester.tap(find.byKey(const ValueKey('nav_scan')));
      await settle(tester);
      await settle(tester);
      expect(find.byType(ScanScreen), findsOneWidget);

      await tester.tap(_visibleBack);
      await settle(tester);
      await settle(tester);
      expect(find.byType(ScanScreen), findsNothing);
      expect(visibleTab(tester), 2, reason: 'on revient sur l\'onglet quitté');
    });

    testWidgets('le bouton retour d\'Android ramène d\'un onglet à l\'accueil', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      await _tapTab(tester, 3);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(visibleTab(tester), 0);
    });

    testWidgets('Profil › Historique des scans, puis Retour', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      await _tapTab(tester, 3);

      await tester.tap(find.byKey(const ValueKey('profile_history')));
      await settle(tester);
      await settle(tester);
      expect(find.byType(HistoryScreen), findsOneWidget);

      await tester.tap(_visibleBack);
      await settle(tester);
      await settle(tester);
      expect(find.byType(HistoryScreen), findsNothing);
      expect(visibleTab(tester), 3);
    });
  });
}
