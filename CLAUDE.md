# CLAUDE.md — Règles pour Claude (prix_vif)

Ce fichier définit des règles **obligatoires** pour toute session de travail sur ce dépôt.

---

## 🎯 Règle 0 — Objectifs de l'app et ergonomie (à relire avant de toucher à un écran)

Décidés par le propriétaire de l'app le 2026-11-23. Toute modification d'interface doit servir ces objectifs et respecter ces règles.

### À quoi sert Prix Vif

1. **Savoir où acheter moins cher** : pour chaque produit, le magasin le moins cher et celui à éviter.
2. **Vérifier un prix en rayon** : produit en main, savoir tout de suite si le prix est bon ici ou s'il est moins cher ailleurs.
3. **Suivre les hausses de prix** : ce qui augmente ou baisse pour un même produit dans un même magasin.
4. **Bien choisir ses produits** : Nutri-Score, équivalent moins cher au kg / L dans la même catégorie.

Hors objectif : le suivi des dépenses ou du budget (onglet retiré en v1.17.0).

### Situation prioritaire : en magasin, produit en main

C'est là que l'app doit être la plus simple. Les autres usages (enregistrer un ticket après les courses, préparer ses courses, analyser les prix) passent après et ne doivent jamais rallonger ce parcours.

### Utilisateurs : le foyer

Quelques proches, pas forcément à l'aise avec la technique. L'app doit se comprendre sans explication.

### Règles d'ergonomie non négociables

1. **Le moins de taps possible.** Depuis l'ouverture de l'app, l'action principale (scanner un produit en rayon et voir où il est moins cher) se fait en 1 ou 2 taps. Une modification qui ajoute un écran, un tap ou un choix obligatoire sur ce parcours ne se fait pas.
2. **Utilisable à une main.** Les actions importantes sont en bas de l'écran (sous le pouce), avec de gros boutons et le moins de saisie au clavier possible. Une action importante ne doit pas être seulement dans le menu ⋮ ou derrière une petite icône en haut de l'écran.

### Avant d'ajouter ou de modifier un écran, un bouton ou un menu

- [ ] À quel objectif ci-dessus sert-il ? Si aucun : ne pas l'ajouter.
- [ ] Combien de taps sur le parcours « en magasin, produit en main », avant et après ? Le nombre ne doit pas augmenter.
- [ ] La fonction existe-t-elle déjà ailleurs dans l'app ? Si oui, améliorer cet endroit plutôt qu'ajouter un nouveau chemin.
- [ ] Le bouton est-il atteignable au pouce, téléphone tenu d'une main ?
- [ ] Un proche peu à l'aise avec la technique comprend-il l'écran sans explication ?
- [ ] En cas de doute sur l'ergonomie : proposer et demander avant de coder.

---

## 📌 Règle 1 — Versionner le README.md à chaque étape

**À chaque étape de travail terminée** (nouvelle fonctionnalité, correction de bug, refactor, changement de dépendance, etc.), le fichier `README.md` doit être mis à jour **et versionné**, en expliquant explicitement ce qui a changé à cette étape.

### Comment faire

1. **Créer la section `## 📋 Historique des versions` en haut du `README.md`** (juste après le titre et les badges) si elle n'existe pas encore. Cette section contient la liste des versions, **la plus récente en premier**. Ne jamais supprimer les entrées précédentes.

2. **Ajouter une entrée pour l'étape** dans cette section, au format exact :

   ```markdown
   ### vX.Y.Z — AAAA-MM-JJ — <titre court de l'étape>

   - **Ajouté** : ce qui a été ajouté
   - **Modifié** : ce qui a été changé
   - **Corrigé** : ce qui a été réparé
   - **Supprimé** : ce qui a été retiré (si applicable)
   ```

   N'utiliser que les catégories pertinentes (laisser tomber celles qui ne s'appliquent pas).

3. **Incrémenter la version sémantique** (SemVer `X.Y.Z`) selon la nature de l'étape :

   | Incrément | Quand l'utiliser | Exemple |
   |-----------|------------------|---------|
   | `MAJOR` (X.0.0) | Changement incompatible, grosse refonte de l'architecture | refonte complète du stockage |
   | `MINOR` (x.Y.0) | Nouvelle fonctionnalité rétrocompatible | nouvel onglet statistiques |
   | `PATCH` (x.y.Z) | Correction de bug, petit ajustement | fix du crash au lancement |

4. **Mettre à jour le pied de page du README** : la ligne `*Dernière mise à jour : ...*` doit refléter la date de l'étape, et la ligne `*Statut : ...*` doit résumer l'état courant.

5. **Synchroniser le contenu du README** : si l'étape a ajouté/modifié une fonctionnalité, mettre à jour les sections concernées (fonctionnalités, utilisation, structure, dépendances...) pour rester cohérent avec le code.

6. **Versionner = commiter** : la mise à jour du README fait partie de l'étape. Le commit git de l'étape doit inclure le `README.md` modifié (ne jamais livrer du code sans son entrée de changelog).

7. **Aligner la version de l'app** : la ligne `version:` de `pubspec.yaml` doit porter la même version `X.Y.Z` que la dernière entrée de l'historique (ex. `version: 1.5.2+1` pour `v1.5.2`). Le numéro de build après `+` n'est incrémenté que pour une publication sur les stores.

### Checklist avant chaque commit

- [ ] Changement d'interface : objectifs et règles d'ergonomie de la Règle 0 respectés
- [ ] Nouvelle entrée `### vX.Y.Z — AAAA-MM-JJ — <titre>` en tête de `## 📋 Historique des versions`
- [ ] Pied de page `*Dernière mise à jour : ...*` et `*Statut : ...*` à jour
- [ ] Sections du README concernées (fonctionnalités, utilisation, structure, dépendances) synchronisées avec le code
- [ ] `version:` de `pubspec.yaml` = version de la dernière entrée
- [ ] `AGENT.MD` mis à jour si l'architecture a changé (Règle 2)

### Exemple d'entrée

```markdown
## 📋 Historique des versions

### v1.2.1 — 2026-07-18 — Fix crash dashboard au lancement

- **Corrigé** : crash de formatage locale (`intl`) dans `dashboard_screen.dart` au chargement des statistiques
- **Corrigé** : `setState` appelé dans `initState` lors de la construction des pages du `IndexedStack`
- **Modifié** : construction dynamique des pages dans `build()` avec clés explicites

### v1.2.0 — 2026-07-10 — Ajout du mode hors-ligne

- **Ajouté** : stockage des scans en attente quand pas de réseau (`PendingOfflineScan`)
- **Ajouté** : traitement automatique des scans en attente au retour de la connectivité
- **Modifié** : `connectivity_service.dart` notifie désormais l'UI des scans en attente
```

### Pourquoi cette règle

Le README est la vitrine du projet : toute personne qui clone le dépôt doit comprendre en 30 secondes ce que fait l'app **et ce qui vient de changer**. Un code livré sans README à jour est un travail incomplet.

---

## 📌 Règle 2 — Cohérence avec AGENT.MD

- `AGENT.MD` reste la **documentation technique d'architecture** (flux, étapes d'implémentation, détails internes). Ne pas y mettre de changelog.
- `README.md` est la **documentation utilisateur + changelog versionné**.
- Si une étape modifie l'architecture décrite dans `AGENT.MD`, mettre les deux à jour dans le même commit.
