// Page d'accueil : point d'entrée de l'app, avec les 3 actions principales
import 'package:flutter/material.dart';
import '../analytics/analytics.dart';
import '../theme.dart';
import '../widgets/home_product_search.dart';
import '../widgets/logo.dart';
import '../widgets/magic_title.dart';

/// Page d'accueil affichée à l'ouverture de l'app.
/// En haut, la recherche d'un produit déjà scanné (dès qu'il y en a un) ;
/// puis une carte par action : scan de code-barres, scan de ticket,
/// analyse des produits et des magasins.
class HomeScreen extends StatelessWidget {
  final VoidCallback onScanBarcode;
  final VoidCallback onScanTicket;
  final VoidCallback onOpenAnalysis;

  /// Produits vus dans au moins un magasin, pour la recherche
  final List<ProductStorePrices> products;

  /// Catégorie d'un produit (recherche par catégorie), `null` si inconnue
  final String? Function(ProductStorePrices product)? categoryOf;

  /// Ouvre la fiche d'un produit trouvé ; sans lui, pas de recherche
  final void Function(String productId, String productName)? onProductTap;

  /// « Comparer dans le tableau de bord » : la recherche reprise dans l'onglet Produits
  final ValueChanged<String>? onSearchInDashboard;

  const HomeScreen({
    super.key,
    required this.onScanBarcode,
    required this.onScanTicket,
    required this.onOpenAnalysis,
    this.products = const [],
    this.categoryOf,
    this.onProductTap,
    this.onSearchInDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const NeonTitle(text: 'PRIX VIF', fontSize: 22),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                const Center(child: AppLogo(size: 72)),
                const SizedBox(height: 16),
                Text(
                  'Que veux-tu faire ?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Scanne tes courses et compare les prix d\'un magasin à l\'autre.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
                ),
                // Retrouver un produit déjà scanné : le magasin le moins cher, puis sa fiche
                if (onProductTap != null && products.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  HomeProductSearch(
                    products: products,
                    categoryOf: categoryOf,
                    onProductTap: onProductTap!,
                    onSeeAll: onSearchInDashboard,
                    onScanBarcode: onScanBarcode,
                  ),
                ],
                const SizedBox(height: 32),
                HomeActionCard(
                  key: const ValueKey('home_scan_barcode'),
                  icon: Icons.qr_code_scanner,
                  title: 'Scanner un code-barres',
                  subtitle: 'Un produit en rayon : sa fiche et son prix',
                  color: AppTheme.primary,
                  onTap: onScanBarcode,
                ),
                const SizedBox(height: 16),
                HomeActionCard(
                  key: const ValueKey('home_scan_ticket'),
                  icon: Icons.receipt_long,
                  title: 'Scanner un ticket de caisse',
                  subtitle: 'Une photo du ticket : tous les articles d\'un coup',
                  color: AppTheme.secondary,
                  onTap: onScanTicket,
                ),
                const SizedBox(height: 16),
                HomeActionCard(
                  key: const ValueKey('home_analysis'),
                  icon: Icons.insights,
                  title: 'Analyser les produits et magasins',
                  subtitle: 'Évolution des prix, magasin le moins cher, économies',
                  color: AppTheme.success,
                  onTap: onOpenAnalysis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grande carte d'action de l'accueil (même style que le bouton
/// « Analyser un produit » du tableau de bord), teintée par [color].
class HomeActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const HomeActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: radius,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: color.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: color, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
