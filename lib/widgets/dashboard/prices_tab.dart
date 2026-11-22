// Onglet « Prix » du tableau de bord
import 'package:flutter/material.dart';

import '../../analytics/analytics.dart';
import '../../theme.dart';
import 'dashboard_card.dart';
import 'section_header.dart';

/// Ce qui a augmenté et ce qui a baissé depuis le dernier achat du même
/// produit dans le même magasin.
class PricesTab extends StatelessWidget {
  final List<PriceChange> increases;
  final List<PriceChange> decreases;

  /// Ouvre la fiche d'un produit (onglet Évolution)
  final void Function(String productId, String productName) onProductTap;

  const PricesTab({
    super.key,
    required this.increases,
    required this.decreases,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('dashboard_prices_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        const DashboardSectionHeader(
          icon: Icons.trending_up,
          title: 'Ce qui a augmenté',
          subtitle: 'Par rapport à ton achat précédent du même produit, dans le même magasin',
        ),
        _ChangesCard(
          key: const ValueKey('price_increases'),
          changes: increases,
          emptyText: 'Aucune hausse depuis tes derniers achats.',
          onProductTap: onProductTap,
        ),
        const SizedBox(height: 24),
        const DashboardSectionHeader(icon: Icons.trending_down, title: 'Ce qui a baissé'),
        _ChangesCard(
          key: const ValueKey('price_decreases'),
          changes: decreases,
          emptyText: 'Aucune baisse depuis tes derniers achats.',
          onProductTap: onProductTap,
        ),
      ],
    );
  }
}

class _ChangesCard extends StatelessWidget {
  final List<PriceChange> changes;
  final String emptyText;
  final void Function(String productId, String productName) onProductTap;

  const _ChangesCard({super.key, required this.changes, required this.emptyText, required this.onProductTap});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: changes.isEmpty
          ? Padding(padding: const EdgeInsets.all(8), child: DashboardEmptyMessage(emptyText))
          : ExpandableList(
              moreLabel: 'autres produits',
              children: [
                for (final change in changes)
                  _PriceChangeRow(change: change, onTap: () => onProductTap(change.productId, change.name)),
              ],
            ),
    );
  }
}

class _PriceChangeRow extends StatelessWidget {
  final PriceChange change;
  final VoidCallback onTap;

  const _PriceChangeRow({required this.change, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = change.isIncrease ? AppTheme.error : AppTheme.success;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    change.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatEuros(change.latestPrice)} chez ${change.storeName} '
                    '(avant ${formatEuros(change.previousPrice)})',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                  ),
                  if (change.isIncrease && change.cheaperStore != null)
                    Text(
                      'Moins cher chez ${change.cheaperStore} : ${formatEuros(change.cheaperPrice!)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                formatSignedPercent(change.percent),
                style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
