// Boutons des barres d'app communs à tous les écrans (Retour et accès à un écran)
import 'package:flutter/material.dart';
import '../theme.dart';

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

/// Bouton rond bleu teinté des barres d'app (Retour, et les autres accès à un
/// écran, comme « Tous mes produits »)
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
