// Onglet « Produits » du tableau de bord : où chaque produit est le moins cher
import 'package:flutter/material.dart';

import '../../analytics/analytics.dart';
import '../../models/product_category.dart';
import '../../theme.dart';
import '../../utils/unit_price.dart';
import 'dashboard_card.dart';
import 'section_header.dart';

enum _ProductsView { byProduct, byCategory }

/// Où acheter chaque produit : vue « Par produit » (le magasin le moins cher
/// et les prix ailleurs) ou « Par catégorie » (toutes les marques d'une
/// catégorie, au kg / L). La recherche porte sur le nom, la marque et la catégorie.
class ProductsTab extends StatefulWidget {
  final List<ProductStorePrices> products;
  final List<CategoryGroup> categoryGroups;

  /// Catégorie d'un produit de [products], `null` si elle est inconnue
  final ProductCategory? Function(ProductStorePrices product) categoryOf;

  /// Ouvre la fiche d'un produit (onglet Magasins)
  final void Function(String productId, String productName) onProductTap;

  /// Place le curseur dans la recherche à l'ouverture (« Où l'acheter ? »)
  final bool autofocusSearch;

  const ProductsTab({
    super.key,
    required this.products,
    this.categoryGroups = const [],
    this.categoryOf = _noCategory,
    required this.onProductTap,
    this.autofocusSearch = false,
  });

  static ProductCategory? _noCategory(ProductStorePrices _) => null;

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  _ProductsView _view = _ProductsView.byProduct;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesProduct(ProductStorePrices product) {
    if (_query.isEmpty) return true;
    final category = widget.categoryOf(product)?.label ?? '';
    return '${product.name} ${product.brand ?? ''} $category'.toLowerCase().contains(_query);
  }

  bool _matchesGroup(CategoryGroup group) {
    if (_query.isEmpty || group.category.label.toLowerCase().contains(_query)) return true;
    return group.offers.any((o) => '${o.name} ${o.brand ?? ''}'.toLowerCase().contains(_query));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('dashboard_products_tab'),
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const ValueKey('dashboard_product_search'),
          controller: _search,
          autofocus: widget.autofocusSearch,
          onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Où l\'acheter ? Produit, marque ou catégorie',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Effacer',
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                    }),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_ProductsView>(
          key: const ValueKey('dashboard_products_view'),
          segments: const [
            ButtonSegment(value: _ProductsView.byProduct, icon: Icon(Icons.local_offer_outlined), label: Text('Par produit')),
            ButtonSegment(value: _ProductsView.byCategory, icon: Icon(Icons.category_outlined), label: Text('Par catégorie')),
          ],
          selected: {_view},
          onSelectionChanged: (selection) => setState(() => _view = selection.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: 20),
        if (widget.products.isEmpty)
          const DashboardCard(
            child: DashboardEmptyMessage(
              'Scanne des produits en choisissant le magasin : tu verras ici où chacun est le moins cher.',
            ),
          )
        else if (_view == _ProductsView.byProduct)
          ..._buildByProduct()
        else
          ..._buildByCategory(),
      ],
    );
  }

  List<Widget> _buildByProduct() {
    final visible = widget.products.where(_matchesProduct).toList();
    if (visible.isEmpty) return [_noMatch()];
    final compared = visible.where((p) => p.hasPriceDifference).toList();
    final single = visible.where((p) => !p.hasPriceDifference).toList();

    return [
      DashboardSectionHeader(
        icon: Icons.emoji_events_outlined,
        title: 'Où chaque produit est le moins cher',
        subtitle: compared.isEmpty ? null : 'Dernier prix relevé dans chaque magasin, du plus gros écart au plus petit',
      ),
      DashboardCard(
        key: const ValueKey('compared_products'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: compared.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: DashboardEmptyMessage(
                  'Aucun produit vu dans deux magasins pour l\'instant. Scanne le même produit dans un autre '
                  'magasin pour comparer.',
                ),
              )
            : _separated([
                for (final product in compared)
                  _ComparedProductRow(
                    product: product,
                    category: widget.categoryOf(product),
                    onTap: () => widget.onProductTap(product.productId, product.name),
                  ),
              ]),
      ),
      if (single.isNotEmpty) ...[
        const SizedBox(height: 24),
        DashboardSectionHeader(
          icon: Icons.storefront_outlined,
          title: 'Vus dans un seul magasin (${single.length})',
          subtitle: 'Scanne-les ailleurs pour savoir s\'ils y sont moins chers',
        ),
        DashboardCard(
          key: const ValueKey('single_store_products'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: _separated([
            for (final product in single)
              _SingleStoreProductRow(
                product: product,
                category: widget.categoryOf(product),
                onTap: () => widget.onProductTap(product.productId, product.name),
              ),
          ]),
        ),
      ],
    ];
  }

  List<Widget> _buildByCategory() {
    final groups = widget.categoryGroups.where(_matchesGroup).toList();
    final uncategorized =
        widget.products.where((p) => widget.categoryOf(p) == null && _matchesProduct(p)).toList();
    if (groups.isEmpty && uncategorized.isEmpty) return [_noMatch()];

    return [
      const DashboardSectionHeader(
        icon: Icons.category_outlined,
        title: 'Comparer par catégorie',
        subtitle: 'Toutes les marques et tous les magasins, du moins cher au plus cher au kg / L',
      ),
      if (groups.isEmpty)
        const DashboardCard(
          child: DashboardEmptyMessage(
            'Aucune catégorie pour l\'instant : elles arrivent d\'Open Food Facts au scan, ou se choisissent '
            'depuis la fiche d\'un produit.',
          ),
        ),
      for (final group in groups) ...[
        _CategoryCard(group: group, onProductTap: widget.onProductTap),
        const SizedBox(height: 12),
      ],
      if (uncategorized.isNotEmpty) ...[
        const SizedBox(height: 12),
        DashboardSectionHeader(
          icon: Icons.help_outline,
          title: 'Sans catégorie (${uncategorized.length})',
          subtitle: 'Touche un produit puis « Choisir une catégorie » sur sa fiche',
        ),
        DashboardCard(
          key: const ValueKey('uncategorized_products'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: _separated([
            for (final product in uncategorized)
              _SingleStoreProductRow(
                product: product,
                onTap: () => widget.onProductTap(product.productId, product.name),
              ),
          ]),
        ),
      ],
    ];
  }

  Widget _noMatch() =>
      DashboardCard(child: DashboardEmptyMessage('Aucun produit ne correspond à « ${_search.text.trim()} ».'));

  static Widget _separated(List<Widget> rows) => Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppTheme.surfaceLight),
            rows[i],
          ],
        ],
      );
}

/// Petite étiquette de catégorie sous le nom d'un produit
class _CategoryTag extends StatelessWidget {
  final ProductCategory category;

  const _CategoryTag(this.category);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              category.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Produit vu dans plusieurs magasins : magasin recommandé en vert, les autres
/// marqués « trop cher » avec l'écart
class _ComparedProductRow extends StatelessWidget {
  final ProductStorePrices product;
  final ProductCategory? category;
  final VoidCallback onTap;

  const _ComparedProductRow({required this.product, this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheapest = product.cheapest;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
              ],
            ),
            if (category != null) _CategoryTag(category!),
            const SizedBox(height: 4),
            _StorePriceLine(
              store: cheapest.storeName,
              verdict: 'recommandé',
              price: formatEuros(cheapest.price),
              highlight: true,
            ),
            for (final other in product.storePrices.skip(1))
              _StorePriceLine(
                store: other.storeName,
                verdict: other.price > cheapest.price + 0.009 ? 'trop cher' : null,
                price: '${formatEuros(other.price)}  (${formatSignedEuros(other.price - cheapest.price)})',
              ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne magasin → prix ; le magasin recommandé est mis en avant
class _StorePriceLine extends StatelessWidget {
  final String store;
  final String? verdict;
  final String price;
  final bool highlight;

  const _StorePriceLine({required this.store, this.verdict, required this.price, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight ? AppTheme.success : AppTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: highlight
                ? const Icon(Icons.thumb_up_alt_outlined, color: AppTheme.success, size: 15)
                : const Icon(Icons.thumb_down_alt_outlined, color: AppTheme.error, size: 13),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: store,
                    style: TextStyle(color: color, fontWeight: highlight ? FontWeight.w700 : FontWeight.w400),
                  ),
                  if (verdict != null)
                    TextSpan(
                      text: ' · $verdict',
                      style: TextStyle(
                        color: highlight ? AppTheme.success : AppTheme.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            price,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Produit vu dans un seul magasin (ou au même prix partout)
class _SingleStoreProductRow extends StatelessWidget {
  final ProductStorePrices product;
  final ProductCategory? category;
  final VoidCallback onTap;

  const _SingleStoreProductRow({required this.product, this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stores = product.storePrices.map((s) => s.storeName).join(', ');
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
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    product.storeCount > 1 ? 'Même prix chez $stores' : 'Vu seulement chez $stores',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                  if (category != null) _CategoryTag(category!),
                ],
              ),
            ),
            Text(
              formatEuros(product.cheapest.price),
              style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Une catégorie : toutes ses offres (produit × magasin), la moins chère au kg / L d'abord
class _CategoryCard extends StatelessWidget {
  final CategoryGroup group;
  final void Function(String productId, String productName) onProductTap;

  const _CategoryCard({required this.group, required this.onProductTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheapest = group.cheapest;
    return DashboardCard(
      key: ValueKey('category_${group.category.id}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.category.label,
            style: theme.textTheme.titleSmall?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
          ),
          Text(
            '${group.productCount} produit${group.productCount > 1 ? 's' : ''} · '
            '${group.storeCount} magasin${group.storeCount > 1 ? 's' : ''}'
            '${group.unit != null ? ' · comparés en ${group.unit!.label}' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          ExpandableList(
            moreLabel: 'autres offres',
            children: [
              for (final offer in group.offers)
                _CategoryOfferRow(
                  offer: offer,
                  comparable: group.isComparable(offer),
                  isCheapest: identical(offer, cheapest),
                  onTap: () => onProductTap(offer.productId, offer.name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryOfferRow extends StatelessWidget {
  final CategoryOffer offer;
  final bool comparable;
  final bool isCheapest;
  final VoidCallback onTap;

  const _CategoryOfferRow({
    required this.offer,
    required this.comparable,
    required this.isCheapest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isCheapest ? AppTheme.success : AppTheme.textPrimary;
    final brand = offer.brand == null || offer.brand!.isEmpty ? '' : ' · ${offer.brand}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: isCheapest ? const Icon(Icons.emoji_events, color: AppTheme.success, size: 15) : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${offer.name}$brand',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${offer.storeName} · ${formatEuros(offer.price)}${comparable ? '' : ' · contenance inconnue'}',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              comparable ? offer.unitPrice!.format() : formatEuros(offer.price),
              style: theme.textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
