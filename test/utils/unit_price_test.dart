import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/utils/unit_price.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR', null);
  });

  group('parsePackageSize', () {
    test('quantité + unité simples', () {
      expect(parsePackageSize(1, 'L'), const PackageSize(1, PriceUnit.liter));
      expect(parsePackageSize(500, 'g'), const PackageSize(0.5, PriceUnit.kilogram));
      expect(parsePackageSize(33, 'cl'), const PackageSize(0.33, PriceUnit.liter));
      expect(parsePackageSize(1.5, 'kg'), const PackageSize(1.5, PriceUnit.kilogram));
      expect(parsePackageSize(6, 'unités'), const PackageSize(6, PriceUnit.piece));
    });

    test('packs', () {
      expect(parsePackageSize(6, 'x 1.5L'), const PackageSize(9, PriceUnit.liter));
      expect(parsePackageSize(null, '6 x 1,5 L'), const PackageSize(9, PriceUnit.liter));
      expect(parsePackageSize(null, '4 × 125 g'), const PackageSize(0.5, PriceUnit.kilogram));
      expect(parsePackageSize(null, '6x25cl'), const PackageSize(1.5, PriceUnit.liter));
    });

    test('chaînes Open Food Facts brutes', () {
      expect(parsePackageSize(null, '℮ 500 g'), const PackageSize(0.5, PriceUnit.kilogram));
      expect(parsePackageSize(null, '1 l'), const PackageSize(1, PriceUnit.liter));
    });

    test('contenance absente ou illisible', () {
      expect(parsePackageSize(null, null), isNull);
      expect(parsePackageSize(2, null), isNull);
      expect(parsePackageSize(null, 'L'), isNull);
      expect(parsePackageSize(3, 'boîtes géantes'), isNull);
    });
  });

  group('UnitPrice', () {
    test('prix au litre et au kilo', () {
      expect(UnitPrice.of(1.49, 1, 'L')!.format(), '1.49 €/L');
      expect(UnitPrice.of(2.99, 500, 'g')!.format(), '5.98 €/kg');
      expect(UnitPrice.of(5.34, 6, 'x 1.5L')!.value, closeTo(0.593, 0.001));
      expect(UnitPrice.of(1.0, null, null), isNull);
    });

    test('ligne de ticket : N articles d\'une contenance donnée deviennent un pack', () {
      final pack = ticketLineQuantity(count: 6, packQuantity: 1.5, packUnit: 'L');
      expect(pack.quantity, 6);
      expect(pack.unit, 'x 1.5 L');
      expect(UnitPrice.of(5.34, pack.quantity, pack.unit)!.value, closeTo(0.593, 0.001));

      final single = ticketLineQuantity(count: 1, packQuantity: 1, packUnit: 'L');
      expect((single.quantity, single.unit), (1.0, 'L'));

      final unknown = ticketLineQuantity(count: 3);
      expect((unknown.quantity, unknown.unit), (3.0, 'unité'));
    });

    test('formattedQuantity sans « .0 » inutile', () {
      final item = ScannedItem(id: '1', name: 'Eau', price: 1, quantity: 6, unit: 'x 1.5L', scanDate: DateTime(2026));
      expect(item.formattedQuantity, '6 x 1.5L');
    });
  });
}
