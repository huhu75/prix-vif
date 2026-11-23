// Accueil : recherche, les deux scans, le magasin le moins cher pour ton
// panier, tes derniers scans et ce qui a augmenté
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import '../widgets/magic_button.dart';
import '../widgets/magic_title.dart';

String _euros(double value) => '${value.toStringAsFixed(2).replaceAll('.', ',')} €';

/// Un produit scanné récemment, avec sa place face aux autres magasins
class _RecentScan {
  final ScannedItem item;
  final String? store;
  final ProductStorePrices? prices;

  _RecentScan(this.item, this.store, this.prices);

  /// Écart avec le magasin le moins cher (0 si c'est le moins cher, `null` si seul)
  double? get gapToCheapest {
    final p = prices;
    if (p == null || p.storeCount < 2) return null;
    return item.price - p.cheapest.price;
  }
}

/// Ouvre la fiche d'un produit sur un onglet donné
typedef ProductTap = void Function(String productId, String productName, {int initialTabIndex});

/// Accueil, premier onglet de la barre du bas
class HomeScreen extends StatelessWidget {
  final List<ScanSession> sessions;
  final VoidCallback onScanBarcode;
  final VoidCallback onScanTicket;

  /// Recherche : ouvre l'onglet Produits, curseur dans la recherche
  final VoidCallback onSearch;

  /// « Tout voir » des derniers scans : onglet Produits
  final VoidCallback onSeeProducts;

  /// « Tout voir » des hausses : onglet Produits, sur l'évolution des prix
  final VoidCallback onSeeIncreases;
  final ProductTap onProductTap;

  // Onglets de la fiche produit
  static const int _evolutionTab = 1;
  static const int _storesTab = 2;

  const HomeScreen({
    super.key,
    required this.sessions,
    required this.onScanBarcode,
    required this.onScanTicket,
    required this.onSearch,
    required this.onSeeProducts,
    required this.onSeeIncreases,
    required this.onProductTap,
  });

  List<_RecentScan> _recentScans(List<ProductStorePrices> allPrices) {
    final byKey = {for (final p in allPrices) p.productKey: p};
    final observations = ProductObservation.fromSessions(sessions)..sort((a, b) => b.date.compareTo(a.date));
    final seen = <String>{};
    return [
      for (final o in observations)
        if (seen.add(o.key)) _RecentScan(o.item, o.storeName, byKey[o.key]),
    ].take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = DashboardStats.fromSessions(sessions);
    final recent = _recentScans(stats.productPrices);
    final basket = stats.shoppingBasket;
    final increases = stats.increases.take(3).toList();
    // Les plus gros écarts de prix entre magasins (déjà triés par écart)
    final savings = stats.productPrices.where((p) => p.hasPriceDifference).take(3).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: ListView(
          // Marge du bas : le bouton Scanner dépasse de la barre
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 56),
          children: [
            // En-tête : logo et titre néon
            Row(
              children: [
                const AppLogo(size: 40),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const NeonTitle(text: 'PRIX VIF', fontSize: 24),
                    Text(
                      'Le bon prix, au bon endroit',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Recherche
            InkWell(
              key: const ValueKey('home_search'),
              onTap: onSearch,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: AppTheme.glassmorphism().copyWith(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Chercher un produit ou un magasin',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rien de scanné : inviter au premier scan (ensuite, le bouton
            // Scanner de la barre du bas suffit)
            if (recent.isEmpty) _FirstScanCard(onScanBarcode: onScanBarcode, onScanTicket: onScanTicket),

            // Où faire ses courses
            if (basket != null) ...[_BasketCard(basket: basket), const SizedBox(height: 24)],

            // Où économiser : les plus gros écarts entre magasins
            if (savings.isNotEmpty) ...[
              _SectionTitle(title: 'Où économiser', action: 'Tout voir', onAction: onSeeProducts),
              const SizedBox(height: 10),
              Container(
                decoration: AppTheme.glassmorphism(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < savings.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                      _SavingRow(
                        product: savings[i],
                        onTap: () => onProductTap(savings[i].productId, savings[i].name, initialTabIndex: _storesTab),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            // Derniers scans
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionTitle(title: 'Tes derniers scans', action: 'Tout voir', onAction: onSeeProducts),
              const SizedBox(height: 10),
              SizedBox(
                height: 178,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _RecentScanCard(
                    scan: recent[i],
                    onTap: () =>
                        onProductTap(productIdOf(recent[i].item), recent[i].item.name, initialTabIndex: _storesTab),
                  ),
                ),
              ),
            ],

            // Ce qui a augmenté
            if (increases.isNotEmpty) ...[
              const SizedBox(height: 24),
              _SectionTitle(title: 'Ce qui a augmenté', action: 'Tout voir', onAction: onSeeIncreases),
              const SizedBox(height: 10),
              Container(
                decoration: AppTheme.glassmorphism(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < increases.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                      _IncreaseRow(
                        change: increases[i],
                        onTap: () =>
                            onProductTap(increases[i].productId, increases[i].name, initialTabIndex: _evolutionTab),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Premier lancement, rien de scanné : à quoi sert l'app et comment commencer
class _FirstScanCard extends StatelessWidget {
  final VoidCallback onScanBarcode;
  final VoidCallback onScanTicket;

  const _FirstScanCard({required this.onScanBarcode, required this.onScanTicket});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('home_first_scan'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primary.withValues(alpha: 0.28), AppTheme.primary.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scanne ton premier produit',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Relève les prix en magasin : Prix Vif te dira où chaque produit est le moins cher, '
            'et ce qui augmente.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 16),
          MagicButton(
            key: const ValueKey('home_scan_barcode'),
            text: 'SCANNER UN PRODUIT',
            icon: Icons.qr_code_scanner,
            onPressed: onScanBarcode,
          ),
          TextButton.icon(
            key: const ValueKey('home_scan_ticket'),
            onPressed: onScanTicket,
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('ou scanner un ticket de caisse'),
          ),
        ],
      ),
    );
  }
}

/// Un produit à acheter ailleurs : le magasin le moins cher, l'économie
class _SavingRow extends StatelessWidget {
  final ProductStorePrices product;
  final VoidCallback onTap;

  const _SavingRow({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cheapest = product.cheapest;
    final expensive = product.mostExpensive;
    return InkWell(
      key: ValueKey('home_saving_${product.productId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.savings_outlined, color: AppTheme.success, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_euros(cheapest.price)} chez ${cheapest.storeName} au lieu de ${_euros(expensive.price)} '
                    'chez ${expensive.storeName}',
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.success.withValues(alpha: 0.5)),
              ),
              child: Text(
                '-${_euros(product.priceDiff)}',
                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Ton panier coûte le moins cher chez … »
class _BasketCard extends StatelessWidget {
  final ShoppingBasketAnalysis basket;

  const _BasketCard({required this.basket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = basket.bestStore;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.success.withValues(alpha: 0.28), AppTheme.success.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.emoji_events, color: AppTheme.success, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ton panier est moins cher chez',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  best.storeName,
                  style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w800),
                ),
                if (basket.savingVsMostExpensive > 0.01)
                  Text(
                    '${_euros(basket.savingVsMostExpensive)} de moins qu\'à ${basket.mostExpensiveStore.storeName}',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
                  ),
              ],
            ),
          ),
          Text(
            _euros(best.total),
            style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;

  const _SectionTitle({required this.title, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onAction,
          child: Text(
            action,
            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// Carte d'un scan récent : image, nom, prix, magasin, place face aux autres magasins
class _RecentScanCard extends StatelessWidget {
  final _RecentScan scan;
  final VoidCallback onTap;

  const _RecentScanCard({required this.scan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final item = scan.item;
    final gap = scan.gapToCheapest;
    final (String? badge, Color badgeColor) = gap == null
        ? (null, AppTheme.textMuted)
        : gap <= 0.009
        ? ('Meilleur prix', AppTheme.success)
        : ('+${_euros(gap)}', AppTheme.error);
    final image = item.imageUrl;
    final hasImage = image != null && image.startsWith('http') && !image.contains('placeholder');

    return GestureDetector(
      key: ValueKey('home_recent_${productIdOf(item)}'),
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(10),
        decoration: AppTheme.glassmorphism().copyWith(borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 64,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: hasImage ? 0.95 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImage
                      ? Image.network(image, fit: BoxFit.contain, errorBuilder: (_, _, _) => _placeholder())
                      : _placeholder(),
                ),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: badgeColor.withValues(alpha: 0.5), blurRadius: 8)],
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              _euros(item.price),
              style: const TextStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              scan.store ?? 'Sans magasin',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => const Center(child: Icon(Icons.shopping_bag_outlined, color: AppTheme.textMuted, size: 28));
}

class _IncreaseRow extends StatelessWidget {
  final PriceChange change;
  final VoidCallback onTap;

  const _IncreaseRow({required this.change, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.trending_up, color: AppTheme.error, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    change.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  Text(change.storeName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text(
              '+${_euros(change.amount)}',
              style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
