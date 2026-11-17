import 'package:flutter/material.dart';

import '../../analytics/analytics.dart';
import '../../theme.dart';
import 'section_header.dart';

/// Section « Où faire mes courses ? » du tableau de bord
class ShoppingBasketSection extends StatefulWidget {
  final ShoppingBasketAnalysis? analysis;

  const ShoppingBasketSection({super.key, required this.analysis});

  @override
  State<ShoppingBasketSection> createState() => _ShoppingBasketSectionState();
}

class _ShoppingBasketSectionState extends State<ShoppingBasketSection> {
  bool _showPlan = false;

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    return Column(
      key: const ValueKey('shopping_basket_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardSectionHeader(
          icon: Icons.shopping_cart_outlined,
          title: 'Où faire mes courses ?',
          subtitle: analysis == null
              ? null
              : analysis.usesRegularPurchases
                  ? 'Coût de tes ${analysis.products.length} produits habituels (achetés au moins 2 fois), un de chaque'
                  : 'Coût de tes ${analysis.products.length} produits scannés en magasin, un de chaque',
        ),
        Container(
          decoration: AppTheme.glassmorphism(),
          padding: const EdgeInsets.all(14),
          child: analysis == null ? _buildEmptyState(context) : _buildContent(context, analysis),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, color: AppTheme.textMuted, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Scanne tes produits dans au moins deux magasins pour savoir lequel revient le moins cher.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ShoppingBasketAnalysis analysis) {
    final theme = Theme.of(context);
    final best = analysis.bestStore;
    final maxTotal = analysis.mostExpensiveStore.total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meilleur magasin
        Row(
          children: [
            const Icon(Icons.emoji_events, color: AppTheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                best.storeName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${best.total.toStringAsFixed(2)} €',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (analysis.savingVsMostExpensive > 0.01)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${analysis.savingVsMostExpensive.toStringAsFixed(2)} € de moins que chez ${analysis.mostExpensiveStore.storeName}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 12),

        // Tous les magasins
        ...analysis.stores.map((store) {
          final isBest = store == best;
          final ratio = maxTotal > 0 ? (store.total / maxTotal).clamp(0.0, 1.0) : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        store.storeName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isBest ? AppTheme.primary : AppTheme.textPrimary,
                          fontWeight: isBest ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${store.total.toStringAsFixed(2)} €',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isBest ? AppTheme.primary : AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: AppTheme.surfaceDark,
                    color: isBest ? AppTheme.primary : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  store.estimatedCount == 0
                      ? 'Tous les prix connus'
                      : 'Prix connus : ${store.pricedCount}/${store.productCount} · ${store.estimatedCount} estimé${store.estimatedCount > 1 ? 's' : ''} au prix moyen observé ailleurs',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted, fontSize: 11),
                ),
              ],
            ),
          );
        }),

        // Panier optimal en combinant les magasins
        if (analysis.optimalSavingVsBestStore > 0.01) ...[
          const Divider(color: AppTheme.surfaceLight),
          InkWell(
            key: const ValueKey('basket_optimal_toggle'),
            onTap: () => setState(() => _showPlan = !_showPlan),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.alt_route, color: AppTheme.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'En combinant les magasins : ${analysis.optimalTotal.toStringAsFixed(2)} € (−${analysis.optimalSavingVsBestStore.toStringAsFixed(2)} €)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(_showPlan ? Icons.expand_less : Icons.expand_more, color: AppTheme.accent, size: 18),
                ],
              ),
            ),
          ),
          if (_showPlan)
            ...analysis.optimalPlan.entries.map((entry) {
              final subtotal = entry.value.fold(0.0, (sum, p) => sum + p.cheapest.value);
              return Padding(
                padding: const EdgeInsets.only(top: 6, left: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key} · ${subtotal.toStringAsFixed(2)} €',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    ...entry.value.map((p) => Text(
                          '• ${p.name} — ${p.cheapest.value.toStringAsFixed(2)} €',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                  ],
                ),
              );
            }),
        ],
      ],
    );
  }
}
