// Comparatif des magasins d'un produit déjà connu : où aller, où ne pas aller
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../theme.dart';

String _euros(double value) => '${value.toStringAsFixed(2)} €';

/// Place d'un magasin dans le comparatif
enum StorePriceRole {
  /// Le moins cher (à égalité éventuellement) : y aller
  best,

  /// Le plus cher, avec un vrai écart : à éviter
  avoid,

  /// Entre les deux
  other,

  /// Un seul magasin connu : rien à comparer
  alone,
}

/// Une ligne du comparatif : un magasin, son prix et sa place
class StorePriceRow {
  final String storeName;
  final double price;

  /// Date du dernier relevé, `null` pour le prix en cours de saisie
  final DateTime? date;

  /// Magasin où l'utilisateur se trouve (celui choisi dans le scanner)
  final bool isCurrentStore;

  /// Écart avec le moins cher (0 pour le moins cher)
  final double diff;
  final StorePriceRole role;

  const StorePriceRow({
    required this.storeName,
    required this.price,
    required this.date,
    required this.isCurrentStore,
    required this.diff,
    required this.role,
  });

  bool get isTyped => date == null;
}

/// Lignes du comparatif, du moins cher au plus cher : le dernier prix de
/// chaque magasin, celui de [currentStore] remplacé par [typedPrice] s'il est saisi.
List<StorePriceRow> buildStorePriceRows(ProductStorePrices prices, {String? currentStore, double? typedPrice}) {
  final entries = <({String store, double price, DateTime? date})>[
    for (final p in prices.storePrices)
      if (!(typedPrice != null && p.storeName == currentStore)) (store: p.storeName, price: p.price, date: p.date),
    if (typedPrice != null && currentStore != null) (store: currentStore, price: typedPrice, date: null),
  ]..sort((a, b) => a.price.compareTo(b.price));
  if (entries.isEmpty) return const [];

  final cheapest = entries.first.price;
  final highest = entries.last.price;
  final compared = entries.length >= 2 && highest - cheapest > 0.009;

  return [
    for (final e in entries)
      StorePriceRow(
        storeName: e.store,
        price: e.price,
        date: e.date,
        isCurrentStore: e.store == currentStore,
        diff: e.price - cheapest,
        role: entries.length == 1
            ? StorePriceRole.alone
            : !compared || e.price - cheapest <= 0.009
                ? StorePriceRole.best
                : highest - e.price <= 0.009
                    ? StorePriceRole.avoid
                    : StorePriceRole.other,
      ),
  ];
}

/// Carte « Où l'acheter ? » d'un produit déjà vu : chaque magasin avec son
/// prix, le moins cher en vert (y aller), le plus cher en rouge (à éviter),
/// et le magasin où l'on se trouve repéré « ici ».
class StorePricesCard extends StatelessWidget {
  final ProductStorePrices prices;

  /// Magasin choisi dans le scanner
  final String? currentStore;

  /// Prix en cours de saisie dans [currentStore]
  final double? typedPrice;

  const StorePricesCard({super.key, required this.prices, this.currentStore, this.typedPrice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = buildStorePriceRows(prices, currentStore: currentStore, typedPrice: typedPrice);
    if (rows.isEmpty) return const SizedBox.shrink();
    final storeCount = rows.length;

    return Container(
      key: const ValueKey('store_prices_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  storeCount == 1 ? 'Déjà vu dans 1 magasin' : 'Où l\'acheter ? $storeCount magasins comparés',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final row in rows) _StorePriceRowTile(row: row),
          const SizedBox(height: 6),
          _verdict(theme, rows),
        ],
      ),
    );
  }

  /// Conclusion pour le magasin où l'on se trouve
  Widget _verdict(ThemeData theme, List<StorePriceRow> rows) {
    final best = rows.first;
    final here = rows.where((r) => r.isCurrentStore).firstOrNull;
    final (Color color, String text) = switch (here?.role) {
      null when rows.length == 1 => (
          AppTheme.textSecondary,
          currentStore == null
              ? 'Scanne-le dans un autre magasin pour comparer.'
              : 'Saisis le prix chez $currentStore pour comparer avec ${best.storeName}.',
        ),
      null => (
          AppTheme.textSecondary,
          'Le moins cher : ${best.storeName} à ${_euros(best.price)}'
              '${currentStore == null ? '' : '. Saisis le prix chez $currentStore pour comparer.'}',
        ),
      StorePriceRole.alone => (AppTheme.textSecondary, 'Scanne-le dans un autre magasin pour comparer.'),
      StorePriceRole.best => (AppTheme.success, 'Tu es au bon endroit : c\'est ici le moins cher.'),
      StorePriceRole.avoid => (
          AppTheme.error,
          'Le plus cher ici : ${_euros(here!.diff)} de moins chez ${best.storeName}.',
        ),
      StorePriceRole.other => (
          AppTheme.warning,
          '${_euros(here!.diff)} de plus ici que chez ${best.storeName}.',
        ),
    };
    return Text(
      text,
      key: const ValueKey('store_prices_verdict'),
      style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
    );
  }
}

class _StorePriceRowTile extends StatelessWidget {
  final StorePriceRow row;

  const _StorePriceRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData? icon, String? label) = switch (row.role) {
      StorePriceRole.best => (AppTheme.success, Icons.emoji_events, 'Le moins cher · vas-y'),
      StorePriceRole.avoid => (AppTheme.error, Icons.block, 'À éviter · +${_euros(row.diff)}'),
      StorePriceRole.other => (AppTheme.textPrimary, null, '+${_euros(row.diff)}'),
      StorePriceRole.alone => (AppTheme.textPrimary, null, null),
    };
    final date = row.date;
    final detail = [
      ?label,
      if (row.isTyped) 'prix saisi' else if (date != null) 'relevé le ${date.day}/${date.month}',
    ].join(' · ');

    return Container(
      key: ValueKey('store_price_row_${row.storeName}'),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: row.role == StorePriceRole.best || row.role == StorePriceRole.avoid
            ? color.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: row.isCurrentStore ? Border.all(color: AppTheme.accent.withValues(alpha: 0.7)) : null,
      ),
      child: Row(
        children: [
          SizedBox(width: 22, child: icon == null ? null : Icon(icon, color: color, size: 18)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.storeName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (row.isCurrentStore) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ici',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: label != null && row.role != StorePriceRole.other ? color : AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _euros(row.price),
            style: theme.textTheme.titleMedium?.copyWith(
              color: row.role == StorePriceRole.other || row.role == StorePriceRole.alone
                  ? AppTheme.textPrimary
                  : color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
