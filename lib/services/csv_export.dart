import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/product_observation.dart';
import '../models.dart';
import '../utils/unit_price.dart';

// ===================================================
// Export CSV des sessions et des articles
// ===================================================
// Format pensé pour Excel / Numbers / LibreOffice en français :
// séparateur « ; », décimales avec une virgule, UTF-8 avec BOM
// (pour que les accents s'affichent correctement dans Excel).

const String csvSeparator = ';';

const List<String> csvHeader = [
  'date',
  'session',
  'type',
  'magasin',
  'produit',
  'marque',
  'code_barres',
  'prix_eur',
  'quantite',
  'unite',
  'prix_normalise',
  'unite_prix_normalise',
  'nutriscore',
  'categories',
];

String _escape(String value) {
  if (value.contains(csvSeparator) || value.contains('"') || value.contains('\n') || value.contains('\r')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String _decimal(double? value, {int digits = 2}) =>
    value == null ? '' : value.toStringAsFixed(digits).replaceAll('.', ',');

String _quantity(double? value) {
  if (value == null) return '';
  final text = value == value.roundToDouble() ? value.toInt().toString() : value.toString();
  return text.replaceAll('.', ',');
}

/// Construit le CSV : une ligne par article, sessions de la plus récente à la plus ancienne.
/// Sans [withBom], le contenu ne commence pas par l'indicateur UTF-8 (utile pour les tests).
String buildArticlesCsv(List<ScanSession> sessions, {bool withBom = true}) {
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final lines = <String>[csvHeader.join(csvSeparator)];

  final sorted = [...sessions]..sort((a, b) => b.date.compareTo(a.date));
  for (final session in sorted) {
    for (final item in session.items) {
      final unitPrice = item.unitPrice;
      lines.add([
        dateFormat.format(item.scanDate),
        session.id,
        session.type,
        resolveStoreName(item, session) ?? '',
        item.name,
        item.brand ?? '',
        item.barcode ?? '',
        _decimal(item.price),
        _quantity(item.quantity),
        item.unit ?? '',
        _decimal(unitPrice?.value),
        unitPrice?.unit.label ?? '',
        item.nutriscore?.toUpperCase() ?? '',
        item.categories?.join(', ') ?? '',
      ].map(_escape).join(csvSeparator));
    }
  }

  // \r\n : fins de ligne attendues par Excel
  return '${withBom ? '﻿' : ''}${lines.join('\r\n')}\r\n';
}

/// Nom du fichier exporté, ex. « prix_vif_export_2026-11-17.csv »
String csvFileName(DateTime now) => 'prix_vif_export_${DateFormat('yyyy-MM-dd').format(now)}.csv';

/// Écrit le CSV dans un fichier temporaire et ouvre la feuille de partage du système
/// (enregistrer dans Fichiers, envoyer par e-mail, Drive…).
/// [origin] : zone du bouton, requise par l'iPad pour placer la feuille de partage.
Future<ShareResult> shareArticlesCsv(List<ScanSession> sessions, {Rect? origin}) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/${csvFileName(DateTime.now())}');
  await file.writeAsString(buildArticlesCsv(sessions));

  final articleCount = sessions.fold<int>(0, (sum, s) => sum + s.items.length);
  return SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Export Prix Vif',
    text: 'Export Prix Vif : ${sessions.length} sessions, $articleCount articles',
    sharePositionOrigin: origin,
  ));
}
