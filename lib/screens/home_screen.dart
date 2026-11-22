// Page d'accueil : point d'entrée de l'app, avec les 3 actions principales
import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import '../widgets/magic_title.dart';

/// Page d'accueil affichée à l'ouverture de l'app.
/// Chaque carte mène à une action : scan de code-barres, scan de ticket,
/// analyse des produits et des magasins.
class HomeScreen extends StatelessWidget {
  final VoidCallback onScanBarcode;
  final VoidCallback onScanTicket;
  final VoidCallback onOpenAnalysis;

  /// « Où acheter un produit ? » : recherche dans l'onglet Produits du tableau de bord
  final VoidCallback? onFindWhereToBuy;

  const HomeScreen({
    super.key,
    required this.onScanBarcode,
    required this.onScanTicket,
    required this.onOpenAnalysis,
    this.onFindWhereToBuy,
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
                if (onFindWhereToBuy != null) ...[
                  const SizedBox(height: 16),
                  HomeActionCard(
                    key: const ValueKey('home_where_to_buy'),
                    icon: Icons.travel_explore,
                    title: 'Où acheter un produit ?',
                    subtitle: 'Cherche un produit ou une catégorie : le magasin le moins cher',
                    color: AppTheme.warning,
                    onTap: onFindWhereToBuy!,
                  ),
                ],
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
