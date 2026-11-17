// Réglage de la clé API Mistral (icône engrenage du scanner)
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/mistral_service.dart';
import '../../services/scan_repository.dart';

/// Ouvre la fenêtre de saisie de la clé API Mistral ; la clé est enregistrée dans Hive.
Future<void> showMistralSettingsDialog(BuildContext context, {ScanRepository? repository}) {
  final messenger = ScaffoldMessenger.of(context);
  final TextEditingController apiController = TextEditingController(
    text: MistralService.apiKey ?? '',
  );
  bool obscureText = true;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.settings, color: AppTheme.primary),
                SizedBox(width: 10),
                Text(
                  'Configuration API',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clé API Mistral AI :',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: apiController,
                  obscureText: obscureText,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Entrez votre clé API Mistral...',
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility : Icons.visibility_off,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          obscureText = !obscureText;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  apiController.text.trim().isEmpty
                      ? '⚠️ Mode Démo actif (sans clé API). L\'analyse des tickets de caisse utilisera des articles factices.'
                      : '✅ Clé API configurée. L\'analyse utilisera l\'API Mistral Vision réelle (modèle mistral-small-latest).',
                  style: TextStyle(
                    color: apiController.text.trim().isEmpty
                        ? AppTheme.warning
                        : AppTheme.accent,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Annuler',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final key = apiController.text.trim();
                  if (repository != null) {
                    await repository.saveMistralApiKey(key);
                  }
                  MistralService.apiKey = key.isNotEmpty ? key : null;
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppTheme.primary,
                      content: Text(
                        key.isNotEmpty
                            ? 'Clé API Mistral enregistrée avec succès'
                            : 'Clé API Mistral supprimée (Mode Démo activé)',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.backgroundDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Sauvegarder'),
              ),
            ],
          );
        },
      );
    },
  );
}
