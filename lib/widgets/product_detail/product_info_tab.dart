// Onglet « Fiche » de la fiche produit : informations Open Food Facts (scores, nutriments)
import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../models/product_analysis_models.dart';
import '../../services/open_food_facts_service.dart';

class ProductInfoTab extends StatelessWidget {
  final OFFProduct? product;
  final ProductAnalysisResult analysis;

  const ProductInfoTab({
    super.key,required this.product, required this.analysis});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (product == null) {
      return const Center(
        child: Text(
          'Aucune information Open Food Facts disponible',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final p = product!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. En-tête Premium avec image, marque, quantité, EAN
          _buildPremiumHeader(context, p),
          const SizedBox(height: 16),

          // 2. Ligne des 3 indices : Nutri-Score, Nova, Eco-Score
          _buildScoresRow(context, p),
          const SizedBox(height: 20),

          // 3. Niveaux de nutriments (Faible / Modéré / Élevé)
          if (p.nutrientLevels.isNotEmpty) ...[
            Text(
              'Repères nutritionnels',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildNutrientLevelsGrid(context, p),
            const SizedBox(height: 20),
          ],

          // 4. Tableau nutritionnel complet
          if (p.nutriments.isNotEmpty) ...[
            Text(
              'Valeurs nutritionnelles (pour 100g)',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildNutritionTable(context, p),
            const SizedBox(height: 20),
          ],

          // 5. Ingrédients
          if (p.ingredients != null && p.ingredients!.isNotEmpty) ...[
            Text(
              'Ingrédients',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: AppTheme.glassmorphism(),
              padding: const EdgeInsets.all(16),
              child: Text(
                p.ingredients!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // 6. Allergènes
          if (p.allergens.isNotEmpty) ...[
            Text(
              'Allergènes',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: p.allergens.map((allergen) => Chip(
                  label: Text(
                    allergen,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
          
          // 7. Catégories
          if (p.categories.isNotEmpty) ...[
            Text(
              'Catégories',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.categories.take(5).map((category) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Text(
                  category,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(BuildContext context, OFFProduct p) {
    final theme = Theme.of(context);
    final sizeLabel = (p.quantity != null) ? '${p.quantity} ${p.unit ?? ""}' : 'Quantité inconnue';

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image du produit
          Hero(
            tag: 'product_image_${p.barcode}',
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                image: p.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(p.imageUrl!),
                        fit: BoxFit.contain,
                      )
                    : null,
                border: Border.all(color: AppTheme.surfaceLight, width: 1),
              ),
              child: p.imageUrl == null
                  ? const Icon(Icons.shopping_bag, size: 40, color: AppTheme.textMuted)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          // Informations textuelles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  p.brand,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'EAN : ${p.barcode}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.scale, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      sizeLabel,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoresRow(BuildContext context, OFFProduct p) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildNutriscoreCard(context, p.nutriscore)),
        const SizedBox(width: 8),
        Expanded(child: _buildNovaCard(context, p.novaGroup)),
        const SizedBox(width: 8),
        Expanded(child: _buildEcoscoreCard(context, p.ecoscore)),
      ],
    );
  }

  Widget _buildNutriscoreCard(BuildContext context, String? score) {
    final theme = Theme.of(context);
    final scoreUpper = score?.toUpperCase();
    final Color color = _getNutriscoreColor(scoreUpper ?? '');
    
    return Container(
      height: 90,
      decoration: AppTheme.glassmorphism(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Nutri-Score',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: scoreUpper != null ? color : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              scoreUpper ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovaCard(BuildContext context, int? group) {
    final theme = Theme.of(context);
    final Color color = _getNovaColor(group);
    
    return Container(
      height: 90,
      decoration: AppTheme.glassmorphism(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Nova',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: group != null ? color : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              group != null ? '$group' : 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEcoscoreCard(BuildContext context, String? score) {
    final theme = Theme.of(context);
    final scoreUpper = score?.toUpperCase();
    final Color color = _getEcoscoreColor(scoreUpper ?? '');
    
    return Container(
      height: 90,
      decoration: AppTheme.glassmorphism(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Éco-Score',
            style: theme.textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: scoreUpper != null ? color : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              scoreUpper ?? 'N/A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientLevelsGrid(BuildContext context, OFFProduct p) {
    final levels = p.nutrientLevels;
    
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildNutrientLevelCard('Matières grasses', levels['fat'], p.nutriments['fat_100g'], 'g'),
        _buildNutrientLevelCard('Acides gras sat.', levels['saturated-fat'], p.nutriments['saturated-fat_100g'], 'g'),
        _buildNutrientLevelCard('Sucres', levels['sugars'], p.nutriments['sugars_100g'], 'g'),
        _buildNutrientLevelCard('Sel', levels['salt'], p.nutriments['salt_100g'], 'g'),
      ],
    );
  }

  Widget _buildNutrientLevelCard(String label, String? level, double? value, String unit) {
    final Color levelColor;
    final String levelText;
    
    switch (level?.toLowerCase()) {
      case 'low':
        levelColor = Colors.green;
        levelText = 'Faible';
        break;
      case 'moderate':
        levelColor = Colors.orange;
        levelText = 'Modéré';
        break;
      case 'high':
        levelColor = Colors.red;
        levelText = 'Élevé';
        break;
      default:
        levelColor = AppTheme.textMuted;
        levelText = 'N/A';
    }

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: levelColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                levelText,
                style: TextStyle(color: levelColor, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (value != null)
                Text(
                  '${value.toStringAsFixed(1)}$unit',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionTable(BuildContext context, OFFProduct p) {
    final n = p.nutriments;
    
    final rows = [
      _buildNutritionRow('Énergie', n['energy-kcal_100g'] ?? (n['energy_100g'] != null ? n['energy_100g']! / 4.184 : null), 'kcal'),
      _buildNutritionRow('Matières grasses', n['fat_100g'], 'g'),
      _buildNutritionRow('  dont Acides gras saturés', n['saturated-fat_100g'], 'g'),
      _buildNutritionRow('Glucides', n['carbohydrates_100g'], 'g'),
      _buildNutritionRow('  dont Sucres', n['sugars_100g'], 'g'),
      _buildNutritionRow('Fibres alimentaires', n['fiber_100g'], 'g'),
      _buildNutritionRow('Protéines', n['proteins_100g'], 'g'),
      _buildNutritionRow('Sel', n['salt_100g'], 'g'),
    ].where((row) => row != null).cast<Widget>().toList();

    return Container(
      decoration: AppTheme.glassmorphism(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Nutriment', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Pour 100g', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: AppTheme.surfaceLight, height: 1),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget? _buildNutritionRow(String label, double? value, String unit) {
    if (value == null) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: label.startsWith(' ') ? AppTheme.textSecondary : AppTheme.textPrimary,
              fontSize: 13,
              fontStyle: label.startsWith(' ') ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          Text(
            '${value.toStringAsFixed(value < 1 ? 3 : 1)} $unit',
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Color _getNutriscoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF038141);
      case 'B': return const Color(0xFF85BB2F);
      case 'C': return const Color(0xFFFECB02);
      case 'D': return const Color(0xFFEE8100);
      case 'E': return const Color(0xFFE63E11);
      default: return AppTheme.textMuted;
    }
  }

  Color _getNovaColor(int? group) {
    switch (group) {
      case 1: return const Color(0xFF00AA55);
      case 2: return const Color(0xFFEEAA00);
      case 3: return const Color(0xFFFF6600);
      case 4: return const Color(0xFFFF0000);
      default: return AppTheme.textMuted;
    }
  }

  Color _getEcoscoreColor(String score) {
    switch (score.toUpperCase()) {
      case 'A': return const Color(0xFF1E824C);
      case 'B': return const Color(0xFF2ECC71);
      case 'C': return const Color(0xFFF1C40F);
      case 'D': return const Color(0xFFE67E22);
      case 'E': return const Color(0xFFE74C3C);
      default: return AppTheme.textMuted;
    }
  }
}
