// Saisie du prix après le scan d'un code-barres
import 'package:flutter/material.dart';
import '../../analytics/analytics.dart';
import '../../theme.dart';
import '../../services/open_food_facts_service.dart';
import '../magic_button.dart';
import '../price_advice_card.dart';
import '../price_card.dart';
import '../store_prices_card.dart';

/// Demande le prix d'un produit scanné ; retourne `null` si l'utilisateur annule.
/// [advise] calcule le conseil d'achat pour le prix saisi (`null` tant qu'il
/// n'y a pas de prix) : la carte s'affiche dès le scan et se met à jour à
/// chaque chiffre tapé.
/// [knownPrices] : prix du produit déjà relevés dans chaque magasin (produit
/// connu) ; le comparatif s'affiche dès le scan, avec [currentStore] repéré
/// « ici » et le prix saisi pris en compte.
Future<double?> showPriceInputSheet(
  BuildContext context,
  String barcode,
  OFFProduct? product, {
  PriceAdvice Function(double? price)? advise,
  ProductStorePrices? knownPrices,
  String? currentStore,
}) async {
  final TextEditingController priceController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  double? typedPrice() {
    final value = double.tryParse(priceController.text.replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(builder: (context, setSheetState) {
      final advice = advise?.call(typedPrice());
      // Avec le comparatif des magasins, le conseil ne sert plus que pour
      // l'équivalent moins cher de la catégorie
      final showAdvice = advice != null && (knownPrices == null || advice.cheaperEquivalent != null);
      return Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Saisir le prix',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Card for product details if available, else fallback generic product layout
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    // Product Image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: product?.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                product!.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.shopping_bag_outlined,
                                  color: AppTheme.textSecondary,
                                  size: 24,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppTheme.textSecondary,
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product?.name ?? 'Produit inconnu',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product?.brand ?? 'Marque inconnue',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (product?.nutriscore != null) ...[
                            const SizedBox(height: 6),
                            NutriScoreBadge(score: product!.nutriscore!),
                          ] else if (product != null &&
                              product.source != 'Open Food Facts' &&
                              product.source != 'Cache') ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppTheme.accent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                product.source,
                                style: const TextStyle(
                                  color: AppTheme.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Produit déjà vu : où l'acheter, où ne pas l'acheter
              if (knownPrices != null) ...[
                const SizedBox(height: 12),
                StorePricesCard(
                  prices: knownPrices,
                  currentStore: currentStore,
                  typedPrice: typedPrice(),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Code-barres scanné : $barcode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              // Conseil d'achat pour le magasin choisi (mis à jour avec le prix saisi)
              if (showAdvice) ...[
                const SizedBox(height: 12),
                PriceAdviceCard(advice: advice),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: priceController,
                onChanged: (_) => setSheetState(() {}),
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accent,
                ),
                decoration: InputDecoration(
                  suffixText: '€',
                  suffixStyle: const TextStyle(fontSize: 24, color: AppTheme.accent),
                  hintText: '0.00',
                  hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.5)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir un prix';
                  }
                  final doubleValue = double.tryParse(value.replaceAll(',', '.'));
                  if (doubleValue == null || doubleValue <= 0) {
                    return 'Veuillez saisir un prix valide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              MagicButton(
                text: 'VALIDER',
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final price = double.parse(priceController.text.replaceAll(',', '.'));
                    Navigator.of(context).pop(price);
                  }
                },
                isPrimary: true,
              ),
            ],
          ),
          ),
        ),
      );
    }),
  );
}
