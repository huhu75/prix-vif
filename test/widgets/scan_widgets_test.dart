import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/services/open_food_facts_service.dart';
import 'package:prix_vif/widgets/scan/price_input_sheet.dart';
import 'package:prix_vif/widgets/scan/scan_mode_selector.dart';
import 'package:prix_vif/widgets/scan/store_selector.dart';
import 'package:prix_vif/widgets/scan/ticket_confirmation_sheet.dart';

/// Les boutons animés (MagicButton) tournent en boucle : pas de pumpAndSettle possible
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Ouvre une feuille via [open] depuis un bouton et renvoie une fonction lisant son résultat
Future<T? Function()> _openFrom<T>(WidgetTester tester, Future<T?> Function(BuildContext) open) async {
  T? result;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => result = await open(context),
          child: const Text('ouvrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await _settle(tester);
  return () => result;
}

void main() {
  testWidgets('saisie du prix : virgule acceptée, prix vide refusé', (tester) async {
    final result = await _openFrom<double>(tester, (context) => showPriceInputSheet(context, '3017620422003', null));

    await tester.tap(find.text('VALIDER'));
    await _settle(tester);
    expect(find.text('Veuillez saisir un prix'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '2,49');
    await tester.tap(find.text('VALIDER'));
    await _settle(tester);
    expect(result(), 2.49);
  });

  testWidgets('confirmation du ticket : lignes identiques distinctes et packs', (tester) async {
    final evian = OFFProduct(
      barcode: '3068320',
      name: 'Evian',
      brand: 'Evian',
      categories: const ['Waters'],
      quantity: 1.5,
      unit: 'L',
      allergens: const [],
      nutrientLevels: const {},
      nutriments: const {},
    );
    final items = [
      ExtractedTicketItem(rawName: 'EVIAN 1.5L', price: 5.34, quantity: 6, matchedProduct: evian, candidates: [evian]),
      ExtractedTicketItem(rawName: 'BAGUETTE', price: 1.10, quantity: 1, candidates: const []),
      ExtractedTicketItem(rawName: 'BAGUETTE', price: 1.10, quantity: 1, candidates: const []),
    ];

    final result = await _openFrom<List<ScannedItem>>(
      tester,
      (context) => showModalBottomSheet<List<ScannedItem>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => TicketConfirmationSheet(items: items, storeName: 'Leclerc', offService: OpenFoodFactsService()),
      ),
    );

    await tester.tap(find.textContaining('IMPORTER 3 ARTICLES'));
    await _settle(tester);

    final imported = result()!;
    expect(imported.length, 3);
    expect(imported.map((i) => i.id).toSet().length, 3);
    expect(imported.every((i) => i.storeName == 'Leclerc'), isTrue);
    final water = imported.first;
    expect((water.quantity, water.unit), (6.0, 'x 1.5 L'));
    expect(water.unitPrice!.format(), '0.59 €/L');
  });

  testWidgets('bascule code-barres / ticket', (tester) async {
    bool? barcodeMode;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ScanModeSelector(isBarcodeMode: true, onChanged: (value) => barcodeMode = value)),
    ));
    await tester.tap(find.text('TICKET'));
    expect(barcodeMode, isFalse);
    await tester.tap(find.text('CODE-BARRES'));
    expect(barcodeMode, isTrue);
  });

  testWidgets('sélecteur de magasin', (tester) async {
    var added = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StoreSelector(
          stores: const ['Carrefour', 'Leclerc'],
          selectedStore: 'Leclerc',
          onSelected: (_) {},
          onAdd: () => added++,
        ),
      ),
    ));
    expect(find.text('Magasin'), findsOneWidget);
    expect(find.text('Leclerc'), findsWidgets);
    await tester.tap(find.byIcon(Icons.add));
    expect(added, 1);
  });
}
