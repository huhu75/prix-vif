import 'package:flutter_test/flutter_test.dart';
import 'package:prix_vif/models.dart';
import 'package:prix_vif/services/csv_export.dart';

void main() {
  final sessions = [
    ScanSession(
      id: 'ancienne',
      date: DateTime(2026, 11, 1, 10),
      type: 'barcode',
      storeName: 'Leclerc',
      items: [
        ScannedItem(id: 'p', name: 'Pain', price: 1.2, scanDate: DateTime(2026, 11, 1, 10, 5)),
      ],
    ),
    ScanSession(
      id: 'recente',
      date: DateTime(2026, 11, 15, 18),
      type: 'ticket',
      items: [
        ScannedItem(
          id: 'l',
          name: 'Lait "demi-écrémé"; bio',
          brand: 'Candia',
          price: 1.49,
          quantity: 6,
          unit: 'x 1L',
          scanDate: DateTime(2026, 11, 15, 18, 30),
          barcode: '3000',
          storeName: 'Carrefour',
          nutriscore: 'b',
          categories: ['Laits', 'Laits demi-écrémés'],
        ),
      ],
    ),
  ];

  test('une ligne par article, sessions récentes d\'abord, format français', () {
    final lines = buildArticlesCsv(sessions, withBom: false).trimRight().split('\r\n');

    expect(lines.first, csvHeader.join(';'));
    expect(lines.length, 3);
    expect(
      lines[1],
      '2026-11-15 18:30;recente;ticket;Carrefour;"Lait ""demi-écrémé""; bio";Candia;3000;1,49;6;x 1L;0,25;€/L;B;Laits, Laits demi-écrémés',
    );
    // Magasin repris de la session quand l'article n'en a pas ; champs vides sinon
    expect(lines[2], '2026-11-01 10:05;ancienne;barcode;Leclerc;Pain;;;1,20;;;;;;');
  });

  test('BOM UTF-8 pour Excel et nom de fichier daté', () {
    expect(buildArticlesCsv(sessions).startsWith('﻿date;'), isTrue);
    expect(csvFileName(DateTime(2026, 11, 17)), 'prix_vif_export_2026-11-17.csv');
  });
}
