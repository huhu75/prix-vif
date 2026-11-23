// Accueil : la recherche fixée en haut (comme Leboncoin), les catégories,
// le magasin le moins cher pour ton panier, où économiser, tes derniers scans
// et ce qui a augmenté
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../models.dart';
import '../models/product_category.dart';
import '../theme.dart';
import '../utils/product_search.dart';
import '../widgets/logo.dart';
import '../widgets/magic_button.dart';

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

  /// Catégorie de chaque produit (clé produit → catégorie), pour les raccourcis
  final Map<String, ProductCategory> categories;

  /// Raccourci de catégorie : onglet Produits, filtré sur cette catégorie
  final ValueChanged<String>? onCategoryTap;

  /// Carte du panier : le détail (onglet Ma liste)
  final VoidCallback? onOpenBasket;

  /// Nombre de raccourcis de catégorie affichés, et minimum pour afficher la
  /// rangée (un ou deux ronds seuls ressemblent à un écran inachevé)
  static const int _maxCategories = 8;
  static const int _minCategories = 3;

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
    this.categories = const {},
    this.onCategoryTap,
    this.onOpenBasket,
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
    final stats = DashboardStats.fromSessions(sessions, categories: categories);
    final recent = _recentScans(stats.productPrices);
    final basket = stats.shoppingBasket;
    final increases = stats.increases.take(3).toList();
    // Les plus gros écarts de prix entre magasins (déjà triés par écart)
    final savings = stats.productPrices.where((p) => p.hasPriceDifference).take(3).toList();
    // Catégories les plus fournies d'abord
    final categoryLabels = ([...stats.categoryGroups]..sort((a, b) => b.offers.length.compareTo(a.offers.length)))
        .map((g) => g.category.label)
        .take(_maxCategories)
        .toList();

    final sections = <Widget>[
      // Raccourcis de catégorie (ronds, défilement horizontal)
      if (categoryLabels.length >= _minCategories && onCategoryTap != null)
        _CategoryShortcuts(labels: categoryLabels, onTap: onCategoryTap!),

      // Rien de scanné : inviter au premier scan (ensuite, le bouton Scanner
      // de la barre du bas suffit)
      if (recent.isEmpty) _FirstScanCard(onScanBarcode: onScanBarcode, onScanTicket: onScanTicket),

      // Où faire ses courses
      // (seulement s'il y a assez de produits en commun pour conclure)
      if (basket != null && basket.comparisonStore != null)
        _BasketCard(basket: basket, comparison: basket.comparisonStore!, onTap: onOpenBasket),

      // Où économiser : les plus gros écarts entre magasins
      if (savings.isNotEmpty)
        _Section(
          title: 'Où économiser',
          onSeeAll: onSeeProducts,
          child: _GlassList(
            children: [
              for (final product in savings)
                _SavingRow(
                  product: product,
                  onTap: () => onProductTap(product.productId, product.name, initialTabIndex: _storesTab),
                ),
            ],
          ),
        ),

      // Derniers scans
      if (recent.isNotEmpty)
        _Section(
          title: 'Tes derniers scans',
          onSeeAll: onSeeProducts,
          child: SizedBox(
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
        ),

      // Ce qui a augmenté
      if (increases.isNotEmpty)
        _Section(
          title: 'Ce qui a augmenté',
          onSeeAll: onSeeIncreases,
          child: _GlassList(
            children: [
              for (final change in increases)
                _IncreaseRow(
                  change: change,
                  onTap: () => onProductTap(change.productId, change.name, initialTabIndex: _evolutionTab),
                ),
            ],
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // En-tête fixe : logo et recherche, comme Leboncoin
            _SearchHeader(onSearch: onSearch),
            Expanded(
              child: ListView.separated(
                // Marge du bas : le bouton Scanner dépasse de la barre
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 56),
                itemCount: sections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 22),
                itemBuilder: (_, i) => sections[i],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// En-tête fixe de l'accueil (comme Leboncoin) : petit logo et grande barre
/// de recherche, qui reste en haut quand on fait défiler
class _SearchHeader extends StatelessWidget {
  final VoidCallback onSearch;

  const _SearchHeader({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          const AppLogo(size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('home_search'),
                onTap: onSearch,
                borderRadius: BorderRadius.circular(26),
                child: Ink(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.45)),
                    boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.15), blurRadius: 14)],
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Rechercher sur Prix Vif',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Raccourcis de catégorie : un rond teinté avec une icône, le nom dessous
class _CategoryShortcuts extends StatelessWidget {
  final List<String> labels;
  final ValueChanged<String> onTap;

  const _CategoryShortcuts({required this.labels, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final label = labels[i];
          return InkWell(
            key: ValueKey('home_category_$label'),
            onTap: () => onTap(label),
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 74,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppTheme.primary.withValues(alpha: 0.3), AppTheme.secondary.withValues(alpha: 0.18)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                    ),
                    child: Icon(categoryIcon(label), color: AppTheme.accent, size: 26),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.15),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Icône d'une catégorie d'après son nom (« Laits demi-écrémés » → bouteille)
IconData categoryIcon(String label) {
  final words = normalizeForSearch(label);
  const icons = <(List<String>, IconData)>[
    (['lait', 'jus', 'soda', 'boisson', 'sirop'], Icons.local_drink_outlined),
    (['eau'], Icons.water_drop_outlined),
    (['cafe'], Icons.local_cafe_outlined),
    (['the ', 'infusion'], Icons.emoji_food_beverage_outlined),
    (['vin', 'biere', 'alcool', 'spiritueux'], Icons.wine_bar_outlined),
    (['pain', 'brioche', 'biscotte', 'viennois'], Icons.bakery_dining_outlined),
    (['yaourt', 'dessert', 'glace', 'creme'], Icons.icecream_outlined),
    (['fromage', 'beurre'], Icons.breakfast_dining_outlined),
    (['chocolat', 'biscuit', 'gateau', 'confiserie', 'bonbon', 'tartiner'], Icons.cookie_outlined),
    (['pate', 'riz', 'cereale', 'farine', 'semoule'], Icons.rice_bowl_outlined),
    (['fruit', 'legume', 'salade', 'compote'], Icons.eco_outlined),
    (['viande', 'jambon', 'poulet', 'charcuterie', 'saucisse', 'boeuf'], Icons.kebab_dining_outlined),
    (['poisson', 'thon', 'saumon', 'sardine'], Icons.set_meal_outlined),
    (['oeuf'], Icons.egg_outlined),
    (['lessive', 'vaisselle', 'entretien', 'nettoyant'], Icons.cleaning_services_outlined),
    (['shampo', 'savon', 'dentifrice', 'gel douche', 'hygiene', 'beaute'], Icons.spa_outlined),
  ];
  for (final (keywords, icon) in icons) {
    if (keywords.any((k) => ' $words '.contains(' $k') || words.startsWith(k.trim()))) return icon;
  }
  return Icons.category_outlined;
}

/// Une section : titre, « Tout voir », contenu
class _Section extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  final Widget child;

  const _Section({required this.title, required this.onSeeAll, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: title, action: 'Tout voir', onAction: onSeeAll),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// Liste de lignes dans une carte en verre dépoli, séparées par un trait
class _GlassList extends StatelessWidget {
  final List<Widget> children;

  const _GlassList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            children[i],
          ],
        ],
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

  /// Magasin comparé au moins cher, sur leurs produits communs
  final StoreBasketCost comparison;

  /// Ouvre le détail du panier
  final VoidCallback? onTap;

  const _BasketCard({required this.basket, required this.comparison, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final best = basket.bestStore;
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.success.withValues(alpha: 0.28), AppTheme.success.withValues(alpha: 0.06)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: radius,
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.45)),
        ),
        child: InkWell(
          key: const ValueKey('home_basket'),
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${_euros(comparison.extraVsBest)} de moins qu\'à ${comparison.storeName}',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
                      ),
                      // Sur quels produits repose la comparaison (aucun prix estimé)
                      Text(
                        'Sur ${comparison.commonWithBest} produits relevés dans les deux',
                        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '−${comparison.percentVsBest.round()} %',
                      style: theme.textTheme.titleLarge?.copyWith(color: AppTheme.success, fontWeight: FontWeight.w800),
                    ),
                    if (onTap != null) const Icon(Icons.chevron_right, color: AppTheme.success),
                  ],
                ),
              ],
            ),
          ),
        ),
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
