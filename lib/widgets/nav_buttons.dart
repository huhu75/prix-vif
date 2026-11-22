// Boutons de navigation communs à tous les écrans (Retour, Accueil)
import 'package:flutter/material.dart';
import '../theme.dart';

/// Navigation globale de l'app.
class AppNavigation {
  AppNavigation._();

  /// Incrémenté à chaque demande de retour à l'accueil. MainScreen l'écoute
  /// pour afficher l'onglet Accueil (les écrans ouverts par-dessus les onglets
  /// ne sont pas sous MainScreen dans l'arbre, ils ne peuvent pas l'appeler).
  static final ValueNotifier<int> homeRequests = ValueNotifier<int>(0);

  /// Ferme tous les écrans ouverts par-dessus les onglets et affiche l'accueil
  static void goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    homeRequests.value++;
  }
}

/// Bouton « Retour » des barres d'app : flèche dans un rond bleu teinté,
/// plus visible qu'une simple flèche. Sans [onPressed], ferme l'écran courant.
class AppBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;

  const AppBackButton({super.key, this.onPressed, this.tooltip = 'Retour'});

  @override
  Widget build(BuildContext context) {
    return AppNavActionButton(
      key: const ValueKey('nav_back'),
      icon: Icons.arrow_back,
      tooltip: tooltip,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// Bouton « Accueil » des écrans ouverts par-dessus les onglets (détails d'une
/// session, sélection et fiche produit) : revient directement à l'accueil.
class AppHomeButton extends StatelessWidget {
  const AppHomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNavActionButton(
      key: const ValueKey('nav_home'),
      icon: Icons.home_outlined,
      tooltip: 'Accueil',
      onPressed: () => AppNavigation.goHome(context),
    );
  }
}

/// Bouton rond bleu teinté des barres d'app (Retour, Accueil, et les autres
/// accès à un écran, comme « Tous mes produits »)
class AppNavActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const AppNavActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        child: IconButton(
          icon: Icon(icon, size: 22),
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            foregroundColor: AppTheme.primary,
            side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.4)),
            fixedSize: const Size(40, 40),
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}
