import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/main.dart';
import 'package:prix_vif/theme.dart';
import 'package:prix_vif/widgets/nav_buttons.dart';

import '../helpers/app_test_helpers.dart';

/// Bouton Retour de l'écran affiché (les onglets cachés en ont un aussi)
final _visibleBack = find.byKey(const ValueKey('nav_back')).hitTestable();
final _visibleHome = find.byKey(const ValueKey('nav_home')).hitTestable();

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(_visibleBack);
  await settle(tester);
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).hitTestable().last);
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

    testWidgets('AppHomeButton ferme tous les écrans ouverts et demande l\'accueil', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.theme,
        home: const Scaffold(body: Text('Racine')),
      ));
      for (final page in ['Page 2', 'Page 3']) {
        navigatorKey.currentState!.push(MaterialPageRoute(
          builder: (_) => Scaffold(appBar: AppBar(actions: const [AppHomeButton()]), body: Text(page)),
        ));
        await tester.pumpAndSettle();
      }
      final requestsBefore = AppNavigation.homeRequests.value;

      await tester.tap(find.byKey(const ValueKey('nav_home')));
      await tester.pumpAndSettle();

      expect(find.text('Racine'), findsOneWidget);
      expect(find.text('Page 2'), findsNothing);
      expect(find.text('Page 3'), findsNothing);
      expect(AppNavigation.homeRequests.value, requestsBefore + 1);
    });
  });

  group('Navigation dans l\'app', () {
    setUpAll(() {
      Hive.init(Directory.systemTemp.createTempSync('prix_vif_nav_test').path);
    });

    setUp(() {
      mockPluginChannels();
      useTallTestScreen();
    });

    tearDown(resetTestScreen);

    testWidgets('l\'accueil n\'a pas de Retour, les onglets en ont un', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      expect(_visibleBack, findsNothing);

      for (final tab in ['Scanner', 'Résultats', 'Dashboard', 'Historique']) {
        await _tapTab(tester, tab);
        expect(_visibleBack, findsOneWidget, reason: 'onglet $tab');
      }
    });

    testWidgets('Retour depuis le Scanner ouvert par l\'accueil revient à l\'accueil', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home_scan_ticket')));
      await settle(tester);
      expect(visibleTab(tester), 1);

      await _tapBack(tester);
      expect(visibleTab(tester), 0);
    });

    testWidgets('Retour remonte les onglets visités, jusqu\'à l\'accueil', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home_analysis'))); // Dashboard
      await settle(tester);
      await _tapTab(tester, 'Historique');
      await _tapTab(tester, 'Résultats');
      expect(visibleTab(tester), 2);

      await _tapBack(tester);
      expect(visibleTab(tester), 4); // Historique
      await _tapBack(tester);
      expect(visibleTab(tester), 3); // Dashboard
      await _tapBack(tester);
      expect(visibleTab(tester), 0); // Accueil
    });

    testWidgets('le bouton retour d\'Android revient à l\'onglet précédent', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);

      await tester.tap(find.byKey(const ValueKey('home_analysis')));
      await settle(tester);
      await _tapTab(tester, 'Historique');

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(visibleTab(tester), 3);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(visibleTab(tester), 0);
    });

    testWidgets('Accueil depuis un écran ouvert par-dessus les onglets', (tester) async {
      await tester.pumpWidget(const PrixVifApp());
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('home_analysis')));
      await settle(tester);
      expect(visibleTab(tester), 3);

      // Écran ouvert par-dessus le Dashboard (comme une fiche produit)
      tester.state<NavigatorState>(find.byType(Navigator).first).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(leading: const AppBackButton(), actions: const [AppHomeButton()]),
          body: const Text('Fiche'),
        ),
      ));
      await settle(tester);
      await settle(tester);
      expect(find.text('Fiche'), findsOneWidget);

      await tester.tap(_visibleHome);
      await settle(tester);
      await settle(tester);

      expect(find.text('Fiche'), findsNothing);
      expect(visibleTab(tester), 0);
    });
  });
}
