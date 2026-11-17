// Onglet « Similaires » de la fiche produit : produits équivalents, du moins cher au plus cher
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/product_analysis_models.dart';
import '../../services/scan_repository.dart';
import '../../screens/product_detail_screen.dart';

// ==========================================
// ONGLET 3 : PRODUITS SIMILAIRES
// ==========================================

class SimilarProductsTab extends StatelessWidget {
  final ProductAnalysisResult analysis;
  final ScanRepository repository;

  /// Transmis aux fiches ouvertes depuis cet onglet (rechargement du Dashboard)
  final Future<void> Function()? onChanged;

  const SimilarProductsTab({
    super.key,
    required this.analysis,
    required this.repository,
    this.onChanged,
  });

  /// Identifiant de fiche : code-barres, sinon nom (tous les scans du produit)
  static String _productIdOf(SimilarProductInfo product) =>
      (product.barcode?.isNotEmpty ?? false) ? product.barcode! : product.productName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final similar = analysis.similarProducts;
    
    if (similar == null || similar.similarProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.compare,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun produit similaire trouvé',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Aucun autre produit de la même catégorie n\'a été scanné',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    final cheapest = similar.cheapestProduct;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Catégorie
          Container(
            decoration: AppTheme.glassmorphism(),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.category, color: AppTheme.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    similar.category,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Produit le moins cher
          if (cheapest != null) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      repository: repository,
                      productId: _productIdOf(cheapest),
                      productName: cheapest.productName,
                      onChanged: onChanged,
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.3),
                      Colors.green.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Le moins cher',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            cheapest.productName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${cheapest.price.toStringAsFixed(2)} €',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (cheapest.unitPrice != null)
                          Text(
                            cheapest.unitPrice!.format(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (cheapest.storeName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            cheapest.storeName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Liste de tous les produits similaires
          Text(
            'Tous les produits similaires',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          
          ...similar.productsSortedByPrice.map((product) {
            final isCheapest = cheapest != null && product.productId == cheapest.productId;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailScreen(
                      repository: repository,
                      productId: _productIdOf(product),
                      productName: product.productName,
                      onChanged: onChanged,
                    ),
                  ),
                );
              },
              child: _SimilarProductCard(
                product: product,
                isCheapest: isCheapest,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SimilarProductCard extends StatelessWidget {
  final SimilarProductInfo product;
  final bool isCheapest;

  const _SimilarProductCard({
    required this.product,
    this.isCheapest = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: isCheapest 
            ? Border.all(color: Colors.green, width: 2)
            : Border.all(color: AppTheme.surfaceLight, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Image
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
              image: product.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(product.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: product.imageUrl == null
                ? Icon(
                    Icons.shopping_bag,
                    color: AppTheme.textMuted,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.brand != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.brand!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (product.storeName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    product.storeName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Prix
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${product.price.toStringAsFixed(2)} €',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isCheapest ? Colors.green : AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (product.unitPrice != null)
                Text(
                  product.unitPrice!.format(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (product.nutriscore != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getNutriscoreColor(product.nutriscore!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    product.nutriscore!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getNutriscoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF038141);
      case 'B': return const Color(0xFF85BB2F);
      case 'C': return const Color(0xFFFECB02);
      case 'D': return const Color(0xFFEE8100);
      case 'E': return const Color(0xFFE63E11);
      default: return AppTheme.textMuted;
    }
  }
}
