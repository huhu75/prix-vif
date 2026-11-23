// Recherche de produit de l'accueil : retrouver un produit en un geste
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../theme.dart';
import '../utils/product_search.dart';

/// Champ de recherche de l'accueil. Vide et sélectionné : les produits
/// scannés récemment. En tapant : les produits qui correspondent (nom,
/// marque, catégorie, magasin), les plus pertinents d'abord, avec le magasin
/// le moins cher. Toucher un produit ouvre sa fiche.
class HomeProductSearch extends StatefulWidget {
  /// Produits vus dans au moins un magasin
  final List<ProductStorePrices> products;

  /// Catégorie d'un produit (pour chercher « lait », « café »…), `null` si inconnue
  final String? Function(ProductStorePrices product)? categoryOf;

  final void Function(String productId, String productName) onProductTap;

  /// « Voir tout » : la même recherche dans l'onglet Produits du tableau de bord
  final ValueChanged<String>? onSeeAll;

  /// Rien trouvé : scanner le produit
  final VoidCallback? onScanBarcode;

  /// Nombre de résultats (et de produits récents) affichés
  static const int maxResults = 5;

  const HomeProductSearch({
    super.key,
    required this.products,
    required this.onProductTap,
    this.categoryOf,
    this.onSeeAll,
    this.onScanBarcode,
  });

  @override
  State<HomeProductSearch> createState() => _HomeProductSearchState();
}

class _HomeProductSearchState extends State<HomeProductSearch> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  ProductSearchQuery _query = ProductSearchQuery('');

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = ProductSearchQuery(''));
  }

  /// Produits les plus récemment relevés d'abord
  List<ProductStorePrices> _recent() {
    DateTime latest(ProductStorePrices p) => p.storePrices.map((s) => s.date).reduce((a, b) => a.isAfter(b) ? a : b);
    final sorted = [...widget.products]..sort((a, b) => latest(b).compareTo(latest(a)));
    return sorted.take(HomeProductSearch.maxResults).toList();
  }

  /// Produits qui correspondent, les plus pertinents d'abord
  List<ProductStorePrices> _results() {
    final scored = <(ProductStorePrices, double)>[
      for (final product in widget.products)
        if (_query.score(
          name: product.name,
          brand: product.brand,
          categories: [?widget.categoryOf?.call(product)],
          stores: product.storePrices.map((p) => p.storeName),
        )
            case final score?)
          (product, score),
    ]..sort((a, b) {
        final byScore = b.$2.compareTo(a.$2);
        return byScore != 0 ? byScore : a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
      });
    return [for (final (product, _) in scored) product];
  }

  void _open(ProductStorePrices product) {
    _focus.unfocus();
    widget.onProductTap(product.productId, product.name);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typing = !_query.isEmpty;
    final results = typing ? _results() : const <ProductStorePrices>[];
    final showRecent = !typing && _focus.hasFocus && widget.products.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('home_product_search'),
          controller: _controller,
          focusNode: _focus,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = ProductSearchQuery(value)),
          onSubmitted: (_) {
            if (results.isNotEmpty) _open(results.first);
          },
          style: theme.textTheme.bodyLarge?.copyWith(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Chercher un produit ou un magasin',
            prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
            suffixIcon: typing
                ? IconButton(icon: const Icon(Icons.close), tooltip: 'Effacer', onPressed: _clear)
                : null,
            filled: true,
            fillColor: AppTheme.surfaceDark,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
            ),
          ),
        ),
        if (showRecent) _panel(theme, 'Récemment scannés', _recent()),
        if (typing && results.isNotEmpty)
          _panel(
            theme,
            results.length > HomeProductSearch.maxResults
                ? '${results.length} produits trouvés'
                : '${results.length} produit${results.length > 1 ? 's' : ''} trouvé${results.length > 1 ? 's' : ''}',
            results.take(HomeProductSearch.maxResults).toList(),
            seeAll: widget.onSeeAll == null ? null : () => widget.onSeeAll!(_controller.text.trim()),
          ),
        if (typing && results.isEmpty) _noResult(theme),
      ],
    );
  }

  Widget _panel(ThemeData theme, String title, List<ProductStorePrices> products, {VoidCallback? seeAll}) {
    return Container(
      key: ValueKey('home_search_panel_$title'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Text(title, style: theme.textTheme.labelMedium?.copyWith(color: AppTheme.textMuted)),
          ),
          for (final product in products) _HomeProductRow(product: product, onTap: () => _open(product)),
          if (seeAll != null)
            TextButton.icon(
              key: const ValueKey('home_search_see_all'),
              onPressed: seeAll,
              icon: const Icon(Icons.insights, size: 18),
              label: const Text('Comparer dans le tableau de bord'),
            ),
        ],
      ),
    );
  }

  Widget _noResult(ThemeData theme) {
    return Container(
      key: const ValueKey('home_search_no_result'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aucun produit scanné ne correspond à « ${_controller.text.trim()} ».',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          if (widget.onScanBarcode != null)
            TextButton.icon(
              onPressed: () {
                _focus.unfocus();
                widget.onScanBarcode!();
              },
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Le scanner pour l\'ajouter'),
            ),
        ],
      ),
    );
  }
}

/// Un produit trouvé : nom, magasin le moins cher et son prix
class _HomeProductRow extends StatelessWidget {
  final ProductStorePrices product;
  final VoidCallback onTap;

  const _HomeProductRow({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cheapest = product.cheapest;
    final compared = product.hasPriceDifference;
    // Le magasin d'abord (coupé en dernier sur un petit écran), la marque ensuite
    final brand = product.brand == null || product.brand!.trim().isEmpty ? '' : ' · ${product.brand}';
    final where = compared
        ? 'Moins cher chez ${cheapest.storeName} · ${product.storeCount} magasins'
        : product.storeCount == 1
            ? 'Vu seulement chez ${cheapest.storeName}'
            : 'Même prix dans ${product.storeCount} magasins';

    return InkWell(
      key: ValueKey('home_search_result_${product.productId}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (compared ? AppTheme.success : AppTheme.primary).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                compared ? Icons.emoji_events_outlined : Icons.local_offer_outlined,
                color: compared ? AppTheme.success : AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$where$brand',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${cheapest.price.toStringAsFixed(2)} €',
              style: theme.textTheme.titleSmall?.copyWith(
                color: compared ? AppTheme.success : AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
