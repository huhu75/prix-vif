import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/widgets/article_edit_dialog.dart';

final _item = ScannedItem(
  id: 'a',
  name: 'Lait',
  brand: 'Candia',
  price: 1.49,
  quantity: 1,
  unit: 'L',
  scanDate: DateTime(2026, 11, 17),
  storeName: 'Carrefour',
);

/// Ouvre la fenêtre d'édition et renvoie une fonction qui lit son résultat
Future<ArticleEditResult? Function()> _openDialog(WidgetTester tester) async {
  ArticleEditResult? result;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => ElevatedButton(
        onPressed: () async => result = await showArticleEditDialog(context, _item),
        child: const Text('ouvrir'),
      ),
    ),
  ));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return () => result;
}

void main() {
  testWidgets('modifier le prix et le magasin', (tester) async {
    final result = await _openDialog(tester);

    expect(find.text('Soit 1.49 €/L'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('edit_price')), '1,99');
    await tester.enterText(find.byKey(const ValueKey('edit_store')), 'Leclerc');
    await tester.pump();
    expect(find.text('Soit 1.99 €/L'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit_save')));
    await tester.pumpAndSettle();

    final updated = (result() as ArticleUpdated).item;
    expect(updated.id, 'a');
    expect(updated.price, 1.99);
    expect(updated.storeName, 'Leclerc');
    expect(updated.quantity, 1);
  });

  testWidgets('un prix invalide bloque l\'enregistrement', (tester) async {
    final result = await _openDialog(tester);

    await tester.enterText(find.byKey(const ValueKey('edit_price')), 'abc');
    await tester.tap(find.byKey(const ValueKey('edit_save')));
    await tester.pumpAndSettle();

    expect(find.text('Prix invalide'), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('la suppression demande une confirmation', (tester) async {
    final result = await _openDialog(tester);

    await tester.tap(find.byKey(const ValueKey('edit_delete')));
    await tester.pump();
    expect(result(), isNull);
    expect(find.text('Confirmer la suppression'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('edit_delete')));
    await tester.pumpAndSettle();
    expect(result(), isA<ArticleDeleted>());
  });
}
