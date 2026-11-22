// Zone du mode ticket : photo, compression, envoi à l'IA
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme.dart';
import '../magic_button.dart';

/// Zone du mode ticket : choix de la photo, aperçu, compression puis analyse par l'IA.
class TicketScanZone extends StatelessWidget {
  final XFile? ticketImage;
  final int? originalSize;
  final int? compressedSize;
  final Uint8List? compressedImageBytes;
  final String? compressionMessage;
  final bool isCompressing;

  /// Analyse IA en cours (affiche le voile de chargement)
  final bool isProcessing;
  final String? errorMessage;
  final void Function(ImageSource source) onCapture;
  final VoidCallback onCompress;
  final VoidCallback onAnalyse;
  final VoidCallback onReset;

  /// Magasin choisi : sans lui, les boutons Appareil photo / Galerie sont grisés
  final bool canCapture;

  const TicketScanZone({
    super.key,
    required this.ticketImage,
    required this.originalSize,
    required this.compressedSize,
    required this.compressedImageBytes,
    required this.compressionMessage,
    required this.isCompressing,
    required this.isProcessing,
    required this.errorMessage,
    required this.onCapture,
    required this.onCompress,
    required this.onAnalyse,
    required this.onReset,
    this.canCapture = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1), width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: ticketImage == null
              ? _buildTicketPlaceholder(context)
              : _buildTicketPreview(),
        ),
        // Bandeau d'erreur (visible aussi en mode ticket, pas seulement en mode code-barres)
        if (errorMessage != null)
          Positioned(
            top: 28,
            left: 28,
            right: 28,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Loader pendant l'analyse IA du ticket
        if (isProcessing)
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3.5),
                    SizedBox(height: 16),
                    Text(
                      'Analyse du ticket par l\'IA...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTicketPlaceholder(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: AppTheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Photographier un ticket',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canCapture
                  ? 'Prenez une photo de votre ticket pour extraire les prix des articles.'
                  : 'Choisis d\'abord ton magasin : le ticket sera enregistré pour ce magasin.',
              key: ValueKey(canCapture ? 'ticket_ready' : 'ticket_no_store'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: canCapture ? AppTheme.textSecondary : AppTheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCameraButton(
                  icon: Icons.camera_alt,
                  label: 'Appareil photo',
                  onTap: canCapture ? () => onCapture(ImageSource.camera) : null,
                ),
                const SizedBox(width: 12),
                _buildCameraButton(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  onTap: canCapture ? () => onCapture(ImageSource.gallery) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: AppTheme.surfaceLight,
        foregroundColor: AppTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  Widget _buildTicketPreview() {
    final double? ratio = (originalSize != null && compressedSize != null)
        ? (1.0 - (compressedSize! / originalSize!)) * 100
        : null;

    return Stack(
      children: [
        Positioned.fill(
          child: compressedImageBytes != null
              ? Image.memory(
                  compressedImageBytes!,
                  fit: BoxFit.cover,
                )
              : Image.file(
                  File(ticketImage!.path),
                  fit: BoxFit.cover,
                ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.85),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompressing)
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primary),
                      SizedBox(height: 12),
                      Text(
                        'Compression en cours...',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else ...[
                if (compressedSize != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceDark.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.compress, color: AppTheme.accent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Optimisation Image (1024px, 80% JPEG)',
                              style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (compressionMessage != null && compressionMessage!.isNotEmpty)
                          Text(
                            compressionMessage!,
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else ...[
                          Text(
                            'Taille originale : ${(originalSize! / 1024).toStringAsFixed(1)} Ko',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          Text(
                            'Taille compressée : ${(compressedSize! / 1024).toStringAsFixed(1)} Ko',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          Text(
                            'Gain : -${ratio!.toStringAsFixed(1)}% de bande passante',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReset,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Reprendre'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MagicButton(
                        text: compressedSize != null ? 'ANALYSER (IA)' : 'OPTIMISER',
                        icon: compressedSize != null ? Icons.auto_awesome : Icons.bolt,
                        onPressed: (isCompressing || isProcessing)
                            ? null
                            : (compressedSize != null ? onAnalyse : onCompress),
                        isLoading: isCompressing || isProcessing,
                        isPrimary: true,
                        height: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
