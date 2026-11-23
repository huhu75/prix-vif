import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/main.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:io';

void main() {
  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    await initializeDateFormatting('fr_FR', null);
  });

  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PrixVifApp());

    // L'app s'ouvre sur l'accueil, avec sa barre de recherche en haut
    expect(find.text('Rechercher sur Prix Vif'), findsOneWidget);
  });
}
