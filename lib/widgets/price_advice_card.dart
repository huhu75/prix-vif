// Conseil d'achat : acheter ce produit dans ce magasin, ou pas
import 'package:flutter/material.dart';

import '../analytics/analytics.dart';
import '../theme.dart';

String _euros(double value) => '${value.toStringAsFixed(2)} €';

/// Carte « Bon prix ici » / « Trop cher ici » / « Pas encore de comparaison »,
/// avec l'équivalent moins cher de la catégorie s'il y en a un.
class PriceAdviceCard extends StatelessWidget {
  final PriceAdvice advice;

  /// Affiche le nom de la catégorie sous le verdict
  final bool showCategory;

  /// Titre à la place de « Bon prix ici » / « Trop cher ici » (ex. sur la fiche produit)
  final String? title;

  const PriceAdviceCard({super.key, required this.advice, this.showCategory = true, this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon, defaultTitle) = switch (advice.verdict) {
      AdviceVerdict.recommended => (AppTheme.success, Icons.thumb_up_alt_outlined, 'Bon prix ici'),
      AdviceVerdict.discouraged => (AppTheme.error, Icons.thumb_down_alt_outlined, 'Trop cher ici'),
      AdviceVerdict.unknown => (AppTheme.textSecondary, Icons.info_outline, 'Pas encore de comparaison'),
    };
    final title = this.title ?? defaultTitle;

    return Container(
      key: ValueKey('price_advice_${advice.verdict.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _detail(),
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
          ),
          if (advice.cheaperEquivalent != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.swap_horiz, color: AppTheme.warning, size: 18),
                const SizedBox(width: 6),
                Expanded(child: _equivalentText(theme)),
              ],
            ),
          ],
          if (showCategory && advice.category != null) ...[
            const SizedBox(height: 6),
            Text(
              'Catégorie : ${advice.category!.label}',
              style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  String _detail() {
    final cheaper = advice.cheaperElsewhere;
    final best = advice.bestElsewhere;
    final others = advice.otherStoreCount;
    switch (advice.verdict) {
      case AdviceVerdict.discouraged:
        return '${_euros(cheaper!.price)} chez ${cheaper.storeName}, soit ${_euros(advice.savingElsewhere!)} de moins'
            '${advice.priceIsLastKnown ? ' (dernier prix relevé ici : ${_euros(advice.price!)})' : ''}.';
      case AdviceVerdict.recommended:
        return 'Aucun autre magasin ne le vend moins cher '
            '(vu dans $others autre${others > 1 ? 's' : ''} magasin${others > 1 ? 's' : ''}'
            '${best != null && best.price > (advice.price ?? 0) + 0.009 ? ', au mieux ${_euros(best.price)} chez ${best.storeName}' : ''}).';
      case AdviceVerdict.unknown:
        if (best != null) return 'Vu à ${_euros(best.price)} chez ${best.storeName}. Saisis le prix pour comparer.';
        return 'Pas encore vu dans un autre magasin : scanne-le ailleurs pour comparer.';
    }
  }

  Widget _equivalentText(ThemeData theme) {
    final offer = advice.cheaperEquivalent!;
    final brand = offer.brand == null || offer.brand!.isEmpty ? '' : ' (${offer.brand})';
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textPrimary),
        children: [
          const TextSpan(text: 'Équivalent moins cher : ', style: TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: '${offer.name}$brand chez ${offer.storeName}, '),
          TextSpan(
            text: offer.unitPrice!.format(),
            style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w700),
          ),
          if (advice.unitPrice != null) TextSpan(text: ' au lieu de ${advice.unitPrice!.format()}'),
        ],
      ),
    );
  }
}
