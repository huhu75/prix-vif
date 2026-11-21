import 'package:flutter/material.dart';

import '../services/open_food_facts_service.dart';
import '../theme.dart';
import '../utils/unit_price.dart';

/// Ouvre la recherche Open Food Facts pour remplacer la fiche associée à un produit.
/// [search] reçoit le texte saisi (nom ou code-barres) et renvoie les candidats.
/// Retourne le produit choisi, ou `null` si l'utilisateur annule.
Future<OFFProduct?> showOffMatchSheet(
  BuildContext context, {
  required String initialQuery,
  required Future<List<OFFProduct>> Function(String query) search,
}) {
  return showModalBottomSheet<OFFProduct>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surfaceDark,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _OffMatchSheet(initialQuery: initialQuery, search: search),
  );
}

class _OffMatchSheet extends StatefulWidget {
  final String initialQuery;
  final Future<List<OFFProduct>> Function(String query) search;

  const _OffMatchSheet({required this.initialQuery, required this.search});

  @override
  State<_OffMatchSheet> createState() => _OffMatchSheetState();
}

class _OffMatchSheetState extends State<_OffMatchSheet> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  List<OFFProduct>? _results;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final text = _query.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.search(text);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Recherche impossible. Vérifie ta connexion et réessaie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Corriger le produit Open Food Facts',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Cherche le bon produit par son nom ou son code-barres, puis touche-le. '
                'Tous les scans de ce produit seront rattachés à la fiche choisie ; leurs prix sont conservés.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('off_match_query'),
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _runSearch(),
                decoration: InputDecoration(
                  hintText: 'Nom du produit ou code-barres',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    key: const ValueKey('off_match_search'),
                    icon: const Icon(Icons.search),
                    onPressed: _runSearch,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildResults(theme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)));
    }
    final results = _results;
    if (results == null) return const SizedBox.shrink();
    if (results.isEmpty) {
      return const Center(
        child: Text(
          'Aucun produit trouvé. Essaie un autre nom ou le code-barres.',
          style: TextStyle(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppTheme.surfaceLight),
      itemBuilder: (context, index) {
        final product = results[index];
        final details = [
          if (product.brand.isNotEmpty) product.brand,
          if (product.quantity != null && product.unit != null)
            '${formatAmount(product.quantity!)} ${product.unit}'
          else if (product.unit != null)
            product.unit!,
          if (product.barcode.isNotEmpty) product.barcode,
        ].join(' · ');
        return ListTile(
          key: ValueKey('off_match_result_$index'),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 48,
              height: 48,
              child: product.imageUrl != null
                  ? Image.network(
                      product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.shopping_bag, color: AppTheme.textMuted),
                    )
                  : const Icon(Icons.shopping_bag, color: AppTheme.textMuted),
            ),
          ),
          title: Text(product.name, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          subtitle: Text(details, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (product.source != 'Open Food Facts' && product.source != 'Cache')
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.source,
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              if (product.nutriscore != null)
                Text(
                  product.nutriscore!.toUpperCase(),
                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w800),
                ),
            ],
          ),
          onTap: () => Navigator.of(context).pop(product),
        );
      },
    );
  }
}
