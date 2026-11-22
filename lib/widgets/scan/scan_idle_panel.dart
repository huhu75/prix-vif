// Zone code-barres tant que la caméra ne tourne pas
import 'package:flutter/material.dart';
import '../../theme.dart';

/// Zone code-barres avant le lancement de la caméra : rappelle l'étape en
/// cours (1. choisir le magasin, 2. appuyer sur SCANNER) et l'éventuelle
/// erreur de caméra.
class ScanIdlePanel extends StatelessWidget {
  final String? store;
  final String? errorMessage;

  const ScanIdlePanel({super.key, required this.store, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = store != null;
    return Container(
      key: ValueKey(ready ? 'scan_idle_ready' : 'scan_idle_no_store'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ready ? Icons.qr_code_scanner : Icons.storefront,
            size: 64,
            color: AppTheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            ready ? 'Prêt à scanner chez $store' : 'Choisis d\'abord ton magasin',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ready
                ? 'Appuie sur SCANNER pour lancer la caméra.'
                : 'Les prix scannés seront enregistrés pour ce magasin. Tu pourras ensuite lancer le scanner.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
