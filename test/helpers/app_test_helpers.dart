// Outils partagés par les tests qui lancent l'app entière (PrixVifApp)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Quelques images (animations des titres, transitions d'onglet)
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Onglet affiché par MainScreen (IndexedStack le plus haut dans l'arbre)
int visibleTab(WidgetTester tester) =>
    tester.widget<IndexedStack>(find.byType(IndexedStack).first).index!;

/// Canaux des plugins appelés par l'app entière (connectivité, caméra) :
/// sans réponse simulée, ils lèvent MissingPluginException pendant le test.
void mockPluginChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => call.method == 'check' ? <String>['wifi'] : null,
  );
  messenger.setMockStreamHandler(
    const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
    MockStreamHandler.inline(onListen: (_, _) {}),
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.steenbakker.mobile_scanner/scanner/method'),
    (call) async => null,
  );
  messenger.setMockStreamHandler(
    const EventChannel('dev.steenbakker.mobile_scanner/scanner/event'),
    MockStreamHandler.inline(onListen: (_, _) {}),
  );
}

/// Écran haut pour voir les 3 cartes de l'accueil sans défiler, assez large
/// pour la police des tests (chaque lettre y est un carré plein, plus large
/// qu'une vraie police : à 390 de large la zone ticket déborderait)
void useTallTestScreen() {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view.physicalSize = const Size(800, 1200);
  view.devicePixelRatio = 1;
}

void resetTestScreen() {
  final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
  view.resetPhysicalSize();
  view.resetDevicePixelRatio();
}
