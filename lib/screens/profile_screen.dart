// Onglet Profil : tes relevés, l'historique des scans, tes magasins, l'export
// et les réglages (clé Mistral, données de démo)
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../models.dart';
import '../services/csv_export.dart';
import '../services/mistral_service.dart';
import '../services/scan_repository.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import '../widgets/magic_title.dart';
import '../widgets/scan/mistral_settings_dialog.dart';
import 'stores_screen.dart';

class ProfileScreen extends StatefulWidget {
  final List<ScanSession> sessions;
  final ScanRepository repository;

  /// Ouvre l'historique des scans
  final VoidCallback onOpenHistory;

  /// Appelé après une modification (magasins, données de démo) pour recharger l'app
  final Future<void> Function() onChanged;

  const ProfileScreen({
    super.key,
    required this.sessions,
    required this.repository,
    required this.onOpenHistory,
    required this.onChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool get _hasDemoData {
    final demoIds = ScanSession.demoSessionIds;
    return widget.sessions.any((s) => demoIds.contains(s.id));
  }

  Future<void> _export(BuildContext tileContext) async {
    final box = tileContext.findRenderObject() as RenderBox?;
    final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await shareArticlesCsv(widget.sessions, origin: origin);
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppTheme.error, content: Text('Export impossible : $e')));
    }
  }

  Future<void> _openStores() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StoresScreen(repository: widget.repository, onChanged: widget.onChanged),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _mistralKey() async {
    await showMistralSettingsDialog(context, repository: widget.repository);
    if (mounted) setState(() {});
  }

  Future<void> _removeDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Retirer les données de démo ?'),
        content: const Text('Seules les sessions d\'exemple sont retirées. Tes propres scans restent.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('confirm_remove_demo'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final removed = await widget.repository.removeDemoData();
    await widget.onChanged();
    messenger.showSnackBar(SnackBar(
      content: Text('$removed session${removed > 1 ? 's' : ''} de démo retirée${removed > 1 ? 's' : ''}'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.sessions;
    final observations = ProductObservation.fromSessions(sessions);
    final products = observations.map((o) => o.key).toSet().length;
    final stores = observations.map((o) => o.storeName).whereType<String>().toSet().length;
    final keyConfigured = MistralService.apiKey?.isNotEmpty ?? false;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(title: const NeonTitle(text: 'PROFIL', fontSize: 20)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 56),
        children: [
          // Tes relevés
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassmorphism(),
            child: Column(
              children: [
                Row(
                  children: [
                    const AppLogo(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tes relevés',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const Text(
                            'Ce que Prix Vif sait de tes courses',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Stat(value: '${observations.length}', label: 'prix relevés', color: AppTheme.primary),
                    _Stat(value: '$products', label: 'produits', color: AppTheme.accent),
                    _Stat(value: '$stores', label: 'magasins', color: AppTheme.success),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ProfileTile(
            key: const ValueKey('profile_history'),
            icon: Icons.history,
            color: AppTheme.primary,
            title: 'Historique des scans',
            subtitle: '${sessions.length} session${sessions.length > 1 ? 's' : ''} · corriger un ticket ou un prix',
            onTap: widget.onOpenHistory,
          ),
          _ProfileTile(
            key: const ValueKey('profile_stores'),
            icon: Icons.storefront,
            color: AppTheme.success,
            title: 'Mes magasins',
            subtitle: 'Ajouter, renommer ou retirer un magasin',
            onTap: _openStores,
          ),
          Builder(
            builder: (tileContext) => _ProfileTile(
              key: const ValueKey('profile_export'),
              icon: Icons.ios_share,
              color: AppTheme.accent,
              title: 'Exporter mes relevés',
              subtitle: 'Un fichier CSV pour Excel ou Numbers',
              onTap: () => _export(tileContext),
            ),
          ),
          _ProfileTile(
            key: const ValueKey('profile_mistral'),
            icon: Icons.key,
            color: AppTheme.secondary,
            title: 'Lecture des tickets (clé Mistral)',
            subtitle: keyConfigured ? 'Clé configurée' : 'À configurer pour scanner un ticket',
            onTap: _mistralKey,
          ),
          if (_hasDemoData)
            _ProfileTile(
              key: const ValueKey('profile_remove_demo'),
              icon: Icons.cleaning_services_outlined,
              color: AppTheme.warning,
              title: 'Retirer les données de démo',
              subtitle: 'Garder seulement tes propres scans',
              onTap: _removeDemo,
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
            ),
          ),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Une ligne du Profil : icône teintée, titre, explication, flèche
class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: AppTheme.glassmorphism().copyWith(borderRadius: radius),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.45)),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppTheme.textMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
