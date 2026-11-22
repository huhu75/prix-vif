// Onglet « Magasins » du tableau de bord
import 'package:flutter/material.dart';

import '../../analytics/analytics.dart';
import '../../theme.dart';
import 'dashboard_card.dart';
import 'section_header.dart';

/// Où faire mes courses (coût du panier habituel par magasin) et, pour chaque
/// magasin, les produits qui y sont le moins chers.
class StoresTab extends StatelessWidget {
  final ShoppingBasketAnalysis? basket;

  /// Magasin → produits qui y sont le moins chers (voir [DashboardStats.cheapestByStore])
  final Map<String, List<ProductStorePrices>> cheapestByStore;

  /// Ouvre la fiche d'un produit (onglet Magasins)
  final void Function(String productId, String productName) onProductTap;

  const StoresTab({
    super.key,
    required this.basket,
    required this.cheapestByStore,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('dashboard_stores_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        BasketCard(analysis: basket),
        const SizedBox(height: 24),
        const DashboardSectionHeader(
          icon: Icons.emoji_events_outlined,
          title: 'Ce que chaque magasin a de moins cher',
          subtitle: 'Parmi les produits vus dans plusieurs magasins',
        ),
        if (cheapestByStore.isEmpty)
          const DashboardCard(
            child: DashboardEmptyMessage(
              'Aucun produit vu dans deux magasins à des prix différents pour l\'instant.',
            ),
          )
        else
          for (final entry in cheapestByStore.entries) ...[
            _StoreWinnersCard(store: entry.key, products: entry.value, onProductTap: onProductTap),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// « Où faire mes courses ? » : coût du panier habituel dans chaque magasin
class BasketCard extends StatelessWidget {
  final ShoppingBasketAnalysis? analysis;

  const BasketCard({super.key, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final analysis = this.analysis;
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
                  ? 'Tes ${analysis.products.length} produits habituels (achetés au moins 2 fois) coûteraient, un de chaque :'
                  : 'Tes ${analysis.products.length} produits scannés en magasin coûteraient, un de chaque :',
        ),
        DashboardCard(
          child: analysis == null
              ? const DashboardEmptyMessage(
                  'Scanne tes produits dans au moins deux magasins pour savoir lequel revient le moins cher.',
                )
              : _buildContent(context, analysis),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ShoppingBasketAnalysis analysis) {
    final theme = Theme.of(context);
    final best = analysis.bestStore;
    final maxTotal = analysis.mostExpensiveStore.total;
    final anyEstimate = analysis.stores.any((s) => s.estimatedCount > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final store in analysis.stores) ...[
          Row(
            children: [
              if (store == best) ...[
                const Icon(Icons.emoji_events, color: AppTheme.success, size: 18),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  store.storeName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: store == best ? AppTheme.success : AppTheme.textPrimary,
                    fontWeight: store == best ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                formatEuros(store.total),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: store == best ? AppTheme.success : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxTotal > 0 ? (store.total / maxTotal).clamp(0.0, 1.0) : 0,
              minHeight: 6,
              backgroundColor: AppTheme.surfaceLight,
              valueColor: AlwaysStoppedAnimation(store == best ? AppTheme.success : AppTheme.textMuted),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${store.pricedCount} prix relevé${store.pricedCount > 1 ? 's' : ''} sur ${store.productCount}',
            style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 10),
        ],
        if (analysis.savingVsMostExpensive > 0.01)
          Text(
            'Chez ${best.storeName}, tu paies ${formatEuros(analysis.savingVsMostExpensive)} de moins '
            'que chez ${analysis.mostExpensiveStore.storeName}.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w600),
          ),
        if (analysis.optimalSavingVsBestStore > 0.01) ...[
          const SizedBox(height: 6),
          Text(
            'En achetant chaque produit là où il est le moins cher : ${formatEuros(analysis.optimalTotal)} '
            '(${formatEuros(analysis.optimalSavingVsBestStore)} de moins).',
            key: const ValueKey('basket_optimal_total'),
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.primary, fontWeight: FontWeight.w600),
          ),
        ],
        if (anyEstimate) ...[
          const SizedBox(height: 8),
          Text(
            'Un prix jamais relevé dans un magasin est estimé d\'après les autres magasins.',
            style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Un magasin et les produits qui y sont le moins chers
class _StoreWinnersCard extends StatelessWidget {
  final String store;
  final List<ProductStorePrices> products;
  final void Function(String productId, String productName) onProductTap;

  const _StoreWinnersCard({required this.store, required this.products, required this.onProductTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashboardCard(
      key: ValueKey('store_winners_$store'),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$store · ${products.length} produit${products.length > 1 ? 's' : ''} moins cher${products.length > 1 ? 's' : ''}',
            style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          ExpandableList(
            moreLabel: 'autres produits',
            children: [
              for (final product in products)
                InkWell(
                  onTap: () => onProductTap(product.productId, product.name),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ),
                        Text(
                          formatEuros(product.cheapest.price),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '  ${formatSignedEuros(-product.priceDiff)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                        ),
                        const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
