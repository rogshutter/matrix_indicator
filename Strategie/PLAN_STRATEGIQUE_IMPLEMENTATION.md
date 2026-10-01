# PLAN STRATÉGIQUE D'IMPLÉMENTATION — RG_SMV V2

## Analyse fidèle des Modules 1 à 10 de la formation SMC

---

## TABLE DES MATIÈRES

1. [Synthèse de la stratégie telle qu'enseignée](#1-synthèse)
2. [Les deux types d'entrée sur le marché](#2-types-entrée)
3. [Séquence exacte du Golden Setup](#3-golden-setup)
4. [Séquence exacte du Concept Entry](#4-concept-entry)
5. [Raffinage PE & SL](#5-raffinage)
6. [Hiérarchie décisionnelle complète](#6-hiérarchie)
7. [Écarts critiques entre code actuel et stratégie](#7-écarts)
8. [Plan d'implémentation par fichier](#8-plan-fichiers)
9. [Règles de signal (flèches)](#9-signaux)
10. [Pièges à éviter](#10-pièges)

---

## 1. SYNTHÈSE DE LA STRATÉGIE TELLE QU'ENSEIGNÉE {#1-synthèse}

### 1.1 Fondations (Module 1 — Structure)

Le marché est composé de **HH/HL** (bullish), **LH/LL** (bearish), et **consolidation** (neutre/latéral).

**Règle 80/20 (Pareto) — FONDAMENTALE** :

- Acheter sur HL dans une structure bullish = 80% de probabilité (continuation de tendance)
- Vendre sur LH dans une structure bearish = 80% de probabilité
- Les 20% restants = retracement/hedging (le faire CONTRE la tendance majeure est risqué)

**Structure Majeure vs Mineure** :

- Structure MAJEURE = les swing points qui BOS (cassent) des structures à GAUCHE
- Structure MINEURE = adjustments internes, ne cassent PAS de structure à gauche
- Seule la structure majeure détermine la direction → les mineurs sont de l'inducement

**3 types de BOS** :

1. **BOS Classique** (changement de tendance) : Casse une structure majeure à gauche. Ex: en bullish, le prix casse le dernier HL → on passe bearish
2. **BOS Continuation** : Casse une structure, mais PAS de structure majeure à gauche. Montre qu'on continue dans la tendance. Crée des **adjustments** (inducements)
3. **BOS TRAP** : Faux BOS qui piège les traders. Le prix casse légèrement, puis revient immédiatement. Nécessite une analyse multi-TF pour le détecter

**Structure de Rotation** :

- Retracement structuré au sein de la tendance
- Zone de neutralité au milieu
- Les causes (accumulation/distribution) peuvent se former EN ROTATION (pas forcément en latéral)

### 1.2 Bougies (Module 2)

**Bougie Manipulatrice** : Grande bougie pleine (full body) qui manipule les retailers → délimite une zone d'offre ou de demande

**Bougie Qui Prend l'Argent (BQA)** : Bougie avec longue mèche qui prend la liquidité → délimite une zone d'offre ou de demande

**Ces deux bougies créent les VRAIES zones S/D**. Ce ne sont pas les Order Blocks classiques.

**Signatures algorithmiques** :

- **Doji** : Avant les grands mouvements impulsifs. Son corps devient une zone S/D
- **2G (deux bougies)** : Pattern de deux bougies qui montre l'intervention algorithmique
- **Signature de Liquidité** : Longues mèches = liquidité en attente

### 1.3 Order Flow & Breaker (Module 3)

**Order Flow** : Pattern en escalier — chaque nouvelle zone S/D vient mitiger (récupérer) la précédente. Confirme la continuation de tendance. Si la bougie BQA précédente est intacte (pas dépassée), le flow continue.

**Breaker Block** : Zone S/D qui a échoué (le prix l'a traversée avec un BOS) → elle change de polarité. Une zone de demande échouée devient une zone d'offre (et inversement).

### 1.4 Cause/Effet (Module 4)

**Cause = Consolidation** (accumulation, distribution, réaccumulation, redistribution)
**Effet = Mouvement** directionnel qui suit

**À l'intérieur de la cause, on doit identifier** :

1. Le **FAIL** : Premier signe du changement de caractère (arrêt + test = LH dans bullish, ou HL dans bearish)
2. La **liquidité** créée par le fail (arrêt, test, renforcement)
3. L'**intention** d'achat ou de vente (via BOS interne)
4. La **prise de liquidité** (sweep du SC-ST ou BC-ST)
5. Le **test** de la prise de liquidité → ENTRÉE

**Suite logique** : Accumulation → Réaccumulation → Distribution → Redistribution

**Intact Buyer / Intact Seller** (TP targets) :

- Intact Buyer = Low non manipulé → target quand on VEND
- Intact Seller = High non manipulé → target quand on ACHÈTE
- Deux destins possibles : BOS (cassé) ou Clean (nettoyé puis retour)

### 1.5 Liquidité (Module 5)

**Inducement** : Tout swing point (LH en bearish, HL en bullish) qui ne donne PAS de BOS de structure majeure = liquidité en attente qui DOIT être prise avant le vrai mouvement.

**EQL/EQH** : Equal lows/highs = concentration de liquidité (confluence avec inducement)

**Trendline de Liquidité** : Les points de touche d'une trendline retail = liquidité en attente pour les big boys

### 1.6 Heures de Tir (Module 6)

**Kill Zones** (heure française) :

- Europe : 9h (hiver) / 8h (été)
- US : 14h (hiver) / 13h (été) + 16h (Chicago)
- Asiatique : 2h (hiver) / 1h (été) + 4h (Tokyo)

**IMPORTANT pour Step Index** : Cet actif Deriv trade 24/7. Les kill zones Forex classiques ne s'appliquent PAS directement. Le filtre kill zone DOIT être désactivé ou adapté.

**High/Low du Mois** : Créé entre le 26 du mois précédent et le 9 du mois courant → indique le biais directionnel mensuel.

### 1.7 Golden Setup — Wyckoff (Modules 7-8)

Voir Section 3 détaillée ci-dessous.

### 1.8 Concept Entry (Module 9)

Voir Section 4 détaillée ci-dessous.

### 1.9 Raffinage PE & SL (Module 10)

Voir Section 5 détaillée ci-dessous.

---

## 2. LES DEUX TYPES D'ENTRÉE SUR LE MARCHÉ {#2-types-entrée}

La formation enseigne exactement **deux types d'entrée** :

### 2.1 Golden Setup (haute probabilité)

- Entrée sur le **test de la prise de liquidité** dans une accumulation ou distribution (Phase C de Wyckoff)
- Nécessite TOUTES les étapes Wyckoff : arrêt tendance, marché latéral, fourchettes, tests, intention (BOS), prise de liquidité
- Le setup le plus puissant mais moins fréquent

### 2.2 Concept Entry (entrée courante)

- Entrée **hors Golden Setup** — quand il n'y a pas de cause Wyckoff, ou après avoir raté le Golden Setup
- Basé sur : structure, inducement (adjustment), prise d'inducement, BOS en LTF, signature candle sur S/D zone
- Plus fréquent, tout aussi exploitable

**HIÉRARCHIE** : Golden Setup > Concept Entry. Mais les deux sont des entrées valides.

---

## 3. SÉQUENCE EXACTE DU GOLDEN SETUP {#3-golden-setup}

### 3.1 Accumulation (achat)

**Pré-requis** : Le prix arrive sur un niveau de DEMANDE décisionnel (HTF)

**Étapes dans l'ordre** :

1. **PS** (Preliminary Support) : Point qui essaie d'arrêter la baisse mais échoue
2. **SC** (Selling Climax) : Point qui réussit à arrêter la baisse → fixe le BAS de la fourchette
3. **AR** (Automatic Rally) : Élargit la fourchette → fixe le HAUT de la fourchette
4. **ST** (Secondary Test) : Teste le SC, renforce sa liquidité. Premier signe du changement de caractère (CHoCH)
5. **UA** (Upthrust Action) : Prend la liquidité du AR. Si avec BOS → intention d'achat
6. **STB** (Spring Test B) : PREMIÈRE prise de liquidité du SC-ST
7. **Spring** (optionnel) : DEUXIÈME prise de liquidité (prend la liquidité du STB). Mouvement brutal
8. **LPS/Test** : Test de la dernière prise de liquidité → **C'EST ICI QU'ON ENTRE** (Phase C)
9. **Phase D-E** : Impulse haussière (l'effet)

**Règle critique** : SC-ST sautent TOUJOURS. C'est GARANTI dans la stratégie.

**Comment réduire la probabilité du Spring** : Si une consolidation se crée SUR le STB → moins de chances d'avoir un Spring (Type 2)

### 3.2 Distribution (vente)

**Pré-requis** : Le prix arrive sur un niveau d'OFFRE décisionnel (HTF)

**Étapes dans l'ordre** :

1. **PSY** (Preliminary Supply) : Point qui essaie d'arrêter l'achat mais échoue
2. **BC** (Buying Climax) : Point qui réussit à arrêter l'achat → fixe le HAUT de la fourchette
3. **AR** (Automatic Reaction) : Élargit vers le bas → fixe le BAS de la fourchette
4. **ST** (Secondary Test) : Teste le BC, renforce sa liquidité
5. **MSO** (Mark-up Sign of Weakness) : Prend la liquidité du AR. Si BOS → intention de vente
6. **UT** (Upthrust) : PREMIÈRE prise de liquidité du BC-ST
7. **UTAD** (Upthrust After Distribution) : DEUXIÈME prise (optionnelle)
8. **LPSY/Test** : Test de la prise de liquidité → **ENTRÉE VENTE**
9. **Phase D-E** : Impulse baissière

### 3.3 Wyckoff Neutralisé Avancé (Module 8)

**Décompte des deux côtés** :

- BC en haut, SC en bas
- ST teste l'OFFRE dans le BC et la DEMANDE dans le SC (on vient tester les bougies BQA/manipulatrice à l'intérieur)
- Liquidité interne (ST) vs Liquidité externe (au-dessus du BC ou en-dessous du SC)
- UT prend la liquidité externe du BC → vendre sur le test pour aller chercher le SC
- STB prend la liquidité externe du SC → acheter sur le test pour aller chercher le BC/ODF

**Structure de Rotation** :

- Même décompte Wyckoff mais DANS la tendance (pas latéral)
- PS, BC, ST sur les highs, SC sur les lows, au sein du mouvement tendanciel

---

## 4. SÉQUENCE EXACTE DU CONCEPT ENTRY {#4-concept-entry}

### 4.1 Contexte

Le Concept Entry intervient dans deux scénarios :

1. **Après un Golden Setup raté** : La cause (accumulation/distribution) a donné l'impulse. On a raté le test Phase C. Comment suivre le flux ?
2. **Sans Golden Setup** : Pas de cause Wyckoff détectée. Le prix arrive sur une zone S/D, on a un BOS + signature → on trade

### 4.2 Séquence exacte (après Golden Setup raté)

```
1. CAUSE déjà formée (accumulation ou distribution déjà jouée)
       ↓
2. IMPULSE sort de la cause → BOS de structure
       ↓
3. BOS CONTINUATION (ne casse PAS de structure majeure à gauche)
       → Crée un ADJUSTMENT (inducement)
       ↓
4. Identifier l'ADJUSTMENT : c'est le swing point créé par le BOS 
   de continuation qui ne casse pas de structure majeure
       ↓
5. ATTENDRE que l'adjustment soit PRIS (liquidity sweep)
       ↓
6. Après la prise de l'adjustment → Descendre en TF
       ↓
7. Chercher un BOS de changement de tendance en LTF
       (Low-High → BOS du LH = intention d'achat en bullish)
       (High-Low → BOS du HL = intention de vente en bearish)
       ↓
8. Chercher un SIGNATURE CANDLE (BQA, manipulatrice, Doji, 2G)
   sur la zone S/D créée par le BOS
       ↓
9. Vérifier la CONFLUENCE multi-TF
   (même niveau de signature sur 45min, 30min, 20min, 15min, 12min, etc.)
       ↓
10. ENTRÉE sur la zone confluente
        SL : au-dessus/en-dessous de la signature candle
        TP : Prochain intact buyer/seller ou inducement non pris
```

### 4.3 Séquence exacte (sans Golden Setup)

```
1. Prix arrive sur un niveau d'OFFRE ou de DEMANDE (HTF)
       ↓
2. Pas de consolidation / pas de cause Wyckoff
       ↓
3. Directement : BOS de structure (classique ou changement de tendance)
       ↓
4. Identifier la zone S/D (bougie manipulatrice / BQA)
       ↓
5. Le prix a pris l'inducement (si présent) ?
       → OUI : on peut entrer
       → NON : attendre
       ↓
6. Descendre TF → chercher BOS + Signature candle
       ↓
7. Confluence multi-TF
       ↓
8. ENTRÉE + SL/TP
```

### 4.4 OUTILS utilisés pour le Concept Entry

Tous les outils de la SMC sont mobilisés :

- Structure de marché (HH/HL/LH/LL)
- Offre et Demande (zones S/D créées par BQA/manipulatrice)
- Liquidité (inducement, EQL/EQH, trendline de liquidité)
- Causes (même hors Golden Setup, une cause peut avoir précédé)
- Order Flow (suivi de l'escalier S/D)
- Fibonacci SMC (Premium/Discount)
- Breaker Block (polarité inversée)
- Heures de tir (si applicable)
- Signatures algorithmiques (Doji, 2G)

---

## 5. RAFFINAGE PE & SL {#5-raffinage}

### 5.1 Principe fondamental

**Raffiné ≠ Affiné**

- Raffiné = PE et SL de QUALITÉ (comme un bon vin)
- Affiné = descendre en M1/secondes chercher l'extrême → rate les entrées, psychologie dégradée

### 5.2 Méthode de raffinage PE

1. Identifier la zone principale (HTF : S/D zone, ODF, breaker block)
2. Scanner cette zone sur PLUSIEURS timeframes intermédiaires :
   - 45min, 30min, 20min, 18min, 16min, 15min, 14min, 13min, 12min, 11min, 10min, 8min, 7min, 6min, 5min
3. Sur chaque TF, chercher la même **signature candle** (Doji, 2G, BQA, Manipulatrice)
4. Le niveau avec le MAXIMUM de confluence = PE optimal
5. PE = corps ou mèche de la signature confluente

### 5.3 Méthode de raffinage SL

Quatre types de SL (du plus agressif au plus sûr) :

1. **Corps du Doji** (agressif) : SL placé au corps du doji/2G signature
2. **Mèche complète** (sûr) : SL au bout de la mèche de la bougie signature
3. **Confluence des corps** : Quand la bougie manipulatrice et la BQA ont leur corps au même niveau → SL à ce niveau
4. **Order Flow interne** : SL au niveau de l'ODF qui a été activé

### 5.4 Limites de SL

La stratégie indique des SL typiques de **4 à 15 pips** selon le raffinage. Le SL doit "rentrer dans la stratégie" (pas plus de ~15-20 pips pour un setup raffiné).

### 5.5 Deux approches de trading

1. **Entrée directe HTF** : Si la zone de confluence est claire sur 20-45min → entrer directement sans descendre en LTF. Le SL est placé sur la signature.
2. **Attendre la réaction** : Attendre que le prix arrive dans la zone, observer la réaction en LTF, puis entrer. Plus sûr mais risque de rater l'entrée.

### 5.6 Targets (TP)

- **TP1** : Premier Intact Buyer/Seller
- **TP2** : Deuxième Intact ou niveau d'adjustment non pris
- **TP avancé** : Niveaux Wyckoff (SC-ST, BC-ST, UT, UTAD non encore pris)
- **Break Even** : Après le premier BOS de continuation dans le sens du trade

---

## 6. HIÉRARCHIE DÉCISIONNELLE COMPLÈTE {#6-hiérarchie}

### Étape 1 : Biais directionnel HTF

```
HTF (H1 ou H4 ou Daily selon l'actif) :
  → Identifier la structure (bullish/bearish/consolidation)
  → Identifier le dernier BOS (classique ou continuation)
  → Identifier la cause précédente (accumulation/distribution) si elle existe
  → Déterminer : on est dans les 80% (continuation) ou les 20% (retracement) ?
```

### Étape 2 : Zones décisionnelles

```
Identifier sur le chart HTF :
  → Zones d'offre/demande (créées par BQA/manipulatrice)
  → Order Flow actif (escalier S/D intact)
  → Breaker Blocks
  → Intact Buyer/Seller (TP targets)
  → Inducements (adjustments non encore pris)
  → EQL/EQH (liquidité concentrée)
```

### Étape 3 : Type d'entrée

```
Le prix arrive sur une zone décisionnelle :
  SI accumulation/distribution détectée (Wyckoff)
    → GOLDEN SETUP : suivre les phases, entrer sur test Phase C
  SINON
    → CONCEPT ENTRY : 
      - BOS de structure + inducement pris
      - Descendre TF, chercher signature candle + BOS LTF
      - Confluence multi-TF
      - Entrer sur la zone confluente
```

### Étape 4 : Validation

```
Avant d'entrer, vérifier :
  ☑ Structure alignée HTF (on trade dans les 80%)
  ☑ Zone S/D décisionnelle (pas n'importe quelle zone)
  ☑ BOS conforme (classique ou continuation, PAS un BOS TRAP)
  ☑ Prise de liquidité / inducement effectuée
  ☑ Signature candle identifiée sur S/D zone
  ☑ SL dans la stratégie (< 15 pips idéalement)
  ☑ R:R minimum acceptable (> 2:1)
```

### Étape 5 : Gestion

```
  → TP1 : Premier intact
  → Break Even : après BOS de continuation dans le sens du trade
  → TP2 : Deuxième intact ou niveau Wyckoff
  → Trailing : suivre l'Order Flow
```

---

## 7. ÉCARTS CRITIQUES ENTRE CODE ACTUEL ET STRATÉGIE {#7-écarts}

### ÉCART 1 — Absence de la séquence Concept Entry réelle (CRITIQUE ★★★)

**Stratégie** : Concept Entry = (1) Identifier adjustment/inducement créé par BOS continuation, (2) Attendre la prise de l'adjustment, (3) Descendre TF, (4) Trouver BOS LTF + signature candle, (5) Entrer.

**Code actuel** (`SMC_ConceptEntry.mqh`) : Tente de combiner S/D zones de `CCandleTypes` + `COrderFlow` + `CLiquidity` simultanément pour valider. Cette approche ne correspond PAS à la stratégie. Résultat : 0 entrées valides.

**Correction requise** : Réécrire `DetectConceptEntries()` pour suivre la séquence exacte décrite en Section 4.

### ÉCART 2 — Classification BOS incomplète (CRITIQUE ★★★)

**Stratégie** : 3 types de BOS fondamentaux :

- BOS Classique (changement de tendance) : casse structure MAJEURE à gauche
- BOS Continuation : casse structure MINEURE seulement
- BOS TRAP : faux BOS

**Code actuel** : Le type de BOS est défini dans `SMC_Structures.mqh` (`ENUM_BOS_SUBTYPE`) mais la distinction "casse à gauche vs pas à gauche" n'est probablement pas implémentée correctement. Le concept d'**adjustment** (swing point créé par un BOS continuation) n'est pas matérialisé.

**Correction requise** :

- Dans `SMC_BOS_ChoCh.mqh`, pour chaque BOS détecté, vérifier s'il casse un swing point à GAUCHE (au-delà du swing immédiat)
- Marquer les BOS comme Classique vs Continuation
- Tout swing point créé dans un BOS Continuation → le marquer comme **adjustment/inducement**

### ÉCART 3 — Inducement détecté mais pas exploité (IMPORTANT ★★)

**Stratégie** : L'inducement (adjustment) est CENTRAL dans le Concept Entry. Il faut :

1. Le détecter (swing who ne BOS pas à gauche)
2. Attendre qu'il soit PRIS (le prix passe au-delà)
3. Après la prise → chercher l'entrée

**Code actuel** : `SInducement` existe dans `SMC_ConceptEntry.mqh` mais le lien "inducement pris → déclencher recherche signature candle" n'est pas fonctionnel.

**Correction requise** : Implémenter la boucle : détecter inducement → surveiller sa prise → déclencher recherche d'entrée

### ÉCART 4 — Confluence multi-TF absente pour Step Index (IMPORTANT ★★)

**Stratégie** : Scanner 45min, 30min, 20min, 18min, etc. pour le même niveau de signature candle.

**Code actuel** : Le raffinage essaie la confluence multi-TF mais Step Index sur Deriv n'a probablement pas tous ces timeframes disponibles. De plus, le raffinage ne se déclenche jamais car il n'y a aucune entrée à raffiner.

**Correction requise** :

- Pour Step Index, utiliser les TFs disponibles (M1, M5, M15, M30, H1, H4, D1)
- La confluence doit chercher la même zone de signature sur M5, M15, M30 au minimum

### ÉCART 5 — Zones S/D mal définies (IMPORTANT ★★)

**Stratégie** : Les zones S/D sont délimitées par les bougies manipulatrices + BQA. PAS par les Order Blocks ICT classiques.

**Code actuel** : Probablement utilise des Order Blocks classiques (dernière bougie baissière avant impulse haussière, etc.) plutôt que les bougies BQA/manipulatrices.

**Correction requise** :

- La zone S/D = du corps au bout de la mèche de la bougie BQA/manipulatrice identifiée
- Une zone S/D est CRÉÉE par une bougie qui manipule ET prend l'argent

### ÉCART 6 — Golden Setup détection trop simpliste (MODÉRÉ ★)

**Stratégie** : Ne PAS voir du Wyckoff partout. Il faut TOUTES les étapes : arrêt tendance → marché latéral → fourchettes → tests → intention (BOS) → prise liquidité → test de la prise → GO. Sans toutes ces étapes, ce n'est PAS un Golden Setup.

**Code actuel** : `SMC_Wyckoff.mqh` détecte probablement des patterns Wyckoff de manière trop large.

**Correction requise** : Renforcer la validation : exiger le passage séquentiel par les phases A→B→C avant de déclarer un Golden Setup

### ÉCART 7 — Kill Zone inadaptée au Step Index (MODÉRÉ ★)

**Stratégie** : Les heures de tir sont basées sur les sessions Forex. Step Index est un indice synthétique Deriv qui trade 24/7 sans corrélation avec les sessions Forex.

**Code actuel** : Le filtre Kill Zone est probablement activé et bloque les signaux en dehors de Londres/NY.

**Correction requise** : Désactiver le filtre Kill Zone pour Step Index. Ou le rendre configurable.

### ÉCART 8 — La fonction DrawFilteredSignalArrows() scanne Refined/Concept entries vides (BLOQUANT ★★★)

**Stratégie** : Les flèches devraient apparaître quand un Golden Setup OU un Concept Entry est détecté.

**Code actuel** : `DrawFilteredSignalArrows()` itère sur les entries de `CConceptEntry` et `CRefinement` qui produisent toutes 0 résultat → 0 flèches.

**Correction requise** : Corriger les modules sous-jacents (Écarts 1-5) pour qu'ils produisent des entrées valides. Ensuite, `DrawFilteredSignalArrows()` fonctionnera naturellement.

---

## 8. PLAN D'IMPLÉMENTATION PAR FICHIER {#8-plan-fichiers}

### Priorité P0 — CRITIQUE (à faire en premier)

#### A. `SMC_BOS_ChoCh.mqh` — Classification BOS

**Objectif** : Distinguer BOS Classique vs BOS Continuation vs BOS Trap

**Implémentation** :

1. Pour chaque BOS détecté, récupérer le swing point C qui a été cassé
2. Scanner les swing points À GAUCHE de C (au-delà du swing immédiat)
3. Si le mouvement post-BOS dépasse un swing point à gauche → **BOS Classique**
4. Si le mouvement post-BOS ne dépasse PAS de swing point à gauche → **BOS Continuation**
5. Si le BOS est immédiatement invalidé (le prix revient et BOS dans l'autre sens en < N barres) → **BOS Trap**
6. Stocker le sous-type dans le champ `ENUM_BOS_SUBTYPE` existant

#### B. `SMC_MarketStructure.mqh` — Adjustments / Inducements

**Objectif** : Identifier les swing points qui sont des adjustments (inducements devant être pris)

**Implémentation** :

1. Pour chaque nouveau swing point HH/HL/LH/LL détecté
2. Vérifier : est-il produit par un BOS Continuation ?
3. Si OUI → le marquer comme `isAdjustment = true`
4. Surveiller en continu : le prix a-t-il dépassé ce swing point ?
5. Si OUI → `adjustmentTaken = true` + `timeTaken = datetime`
6. Ajouter au struct `SSwingPoint` les champs : `isAdjustment`, `adjustmentTaken`, `timeTaken`

#### C. `SMC_ConceptEntry.mqh` — RÉÉCRITURE Concept Entry

**Objectif** : Implémenter la vraie séquence Concept Entry

**Nouvelle logique de `DetectConceptEntries()`** :

```
POUR chaque barre récente du chart (lookback ~ 200 barres) :

  ÉTAPE 1 : Y a-t-il un adjustment qui a été PRIS récemment ?
    → Scanner les swing points marqués isAdjustment=true
    → Vérifier si adjustmentTaken=true ET timeTaken est récent (< N barres)
    → Si OUI : procéder à l'étape 2
    → Si NON : pas de Concept Entry possible ici

  ÉTAPE 2 : Après la prise de l'adjustment, y a-t-il un BOS en LTF ?
    → Scanner les BOS détectés APRÈS le timeTaken de l'adjustment
    → Le BOS doit être un BOS Classique (changement de tendance local)
    → Bullish : le prix casse un LH → intention d'achat
    → Bearish : le prix casse un HL → intention de vente

  ÉTAPE 3 : Y a-t-il une signature candle sur la zone S/D ?
    → Identifier la zone S/D créée par le BOS (bougie avant le BOS = OB)
    → Scanner les bougies dans cette zone pour :
      - Doji (corps < 30% du range, ratio mèche/corps > 2)
      - 2G (deux bougies connectées formant un pattern)
      - BQA (longue mèche qui a pris la liquidité)
      - Manipulatrice (grand corps plein qui manipule)
    → Si signature trouvée : procéder

  ÉTAPE 4 : Le prix est-il revenu tester la zone ?
    → Le prix doit revenir DANS la zone S/D après le BOS
    → C'est le moment de l'entrée

  ÉTAPE 5 : Construire l'entrée
    → Direction : BULL si BOS achat, BEAR si BOS vente
    → PE : corps de la signature candle (ou zone S/D)
    → SL : au-delà de la signature candle (mèche ou corps selon raffinage)
    → TP1 : prochain Intact Buyer (si SELL) ou Intact Seller (si BUY)
    → TP2 : deuxième Intact ou inducement non pris
    → Vérifier R:R >= 2
    → Marquer isValid=true
```

**Alternative simplifiée pour les entrées sur ODF (Order Flow)** :

```
SI BOS détecté + pas d'adjustment spécifique :
  → Chercher Order Flow actif (escalier S/D, chaque zone mitigue la précédente)
  → Chercher la dernière zone ODF non encore testée
  → Si signature candle dans cette zone + concordance structurelle → Concept Entry

```

### Priorité P1 — IMPORTANT

#### D. `SMC_CandleTypes.mqh` — Zones S/D correctes

**Objectif** : Les zones S/D doivent être créées uniquement par les bougies BQA/manipulatrice

**Vérification** :

1. S'assurer que `DetectZones()` crée les zones à partir de : Doji, BQA, Manipulatrice
2. La zone = du corps au bout de la mèche de la bougie
3. Pas de zones créées par simple "dernière bougie baissière avant impulse" (ce serait un OB ICT, pas la stratégie enseignée)

#### E. `SMC_Wyckoff.mqh` — Validation séquentielle

**Objectif** : Ne déclarer un Golden Setup que si TOUTES les étapes sont présentes dans l'ordre

**Vérification** :

1. Accumulation : PS → SC → AR → ST → (UA optionnel) → STB/Spring → Test
2. Chaque étape doit être validée avant de passer à la suivante
3. Si le marché ne devient PAS latéral (pas de fourchette) → pas de Golden Setup
4. Si pas d'intention (BOS) → pas de Golden Setup

#### F. `SMC_Liquidity.mqh` — Intact Buyer/Seller comme TP

**Objectif** : Utiliser les intacts comme targets, pas comme filtres

**Vérification** :

1. `GetNextIntactBuyer(currentPrice)` → retourne le prochain low intact en-dessous du prix (TP pour SELL)
2. `GetNextIntactSeller(currentPrice)` → retourne le prochain high intact au-dessus du prix (TP pour BUY)
3. Ces niveaux alimentent les TP1/TP2 des entrées Golden et Concept

### Priorité P2 — MODÉRÉ

#### G. `SMC_Refinement.mqh` — Raffinage fonctionnel

**Objectif** : Raffiner les entrées déjà détectées par ConceptEntry ou Wyckoff

**Implémentation** :

1. Prendre une entrée valide (SConceptEntry ou Golden Setup avec zone S/D)
2. Scanner la zone sur les TFs disponibles : M5, M15, M30 (pour Step Index)
3. Chercher des signatures candles sur chaque TF dans la même zone
4. Compter les confluences
5. Ajuster PE au niveau le plus confluent
6. Calculer les différents niveaux de SL (body doji, wick, confluence corps, ODF interne)
7. Choisir le SL le plus approprié qui respecte la limite de pips

#### H. `RG_SMV_V2.mq5` — Signal Arrows

**Objectif** : Afficher une flèche quand un signal est validé

**Implémentation** :

1. À chaque nouvelle barre, appeler `g_conceptEntry.DetectConceptEntries()`
2. Si une entrée valide est trouvée → dessiner une flèche
3. Également scanner `g_wyckoff` pour les Golden Setups
4. Ajouter une ligne TP et une ligne SL pour chaque signal
5. Supprimer les signaux expirés

#### I. `RG_SMV_V2.mq5` — Supprimer le filtre Kill Zone

**Objectif** : Ne pas filtrer les signaux par session pour Step Index

---

## 9. RÈGLES DE SIGNAL (FLÈCHES) {#9-signaux}

### Signal ACHAT (flèche verte ▲)

Conditions requises (AU MOINS l'une des deux catégories) :

**Catégorie A — Golden Setup ACHAT** :

1. Structure HTF bearish → accumulation détectée sur zone de demande décisionnelle
2. Phases SC → AR → ST → (UA) → STB/Spring complétées
3. Prix teste le STB/Spring (Phase C)
4. Entrée sur le test

**Catégorie B — Concept Entry ACHAT** :

1. Structure HTF bullish (on est dans les 80%)
2. BOS Continuation détecté → adjustment créé
3. Adjustment PRIS (liquidity sweep du swing point)
4. BOS de changement de tendance en LTF (Low-High → BOS du LH)
5. Signature candle identifiée sur zone de demande
6. OU : Order Flow haussier intact + retour sur zone ODF + signature candle

### Signal VENTE (flèche rouge ▼)

(Symétrique parfait de l'achat)

### Labels informationnels

Chaque flèche doit être accompagnée de :

- Type : "GS" (Golden Setup) ou "CE" (Concept Entry) ou "ODF" (Order Flow)
- Direction : BUY / SELL
- SL : prix du stop loss
- TP1 : prix du premier target
- R:R : ratio calculé

---

## 10. PIÈGES À ÉVITER {#10-pièges}

### Piège 1 : Voir du Wyckoff partout

La formation insiste lourdement : NE PAS voir des accumulations/distributions partout. Il faut TOUTES les étapes (arrêt, latéralisation, fourchettes, tests, intention, prise de liquidité). Sans tout ça, ce n'est PAS un Golden Setup.

### Piège 2 : Confondre BOS Continuation et BOS Classique

Un BOS Continuation ne change PAS la tendance. Il crée un adjustment (inducement). Ne pas le traiter comme un changement de tendance.

### Piège 3 : Affiner au lieu de Raffiner

Ne PAS descendre en M1 ou secondes pour chercher l'entrée parfaite. Rester sur M5-M15-M30 pour le raffinage. La stratégie dit explicitement que "tous les gars qui vous disent de rentrer en M1, c'est du blabla".

### Piège 4 : Ignorer l'adjustment

L'adjustment DOIT être pris avant d'entrer en Concept Entry. Si l'adjustment n'a pas encore sauté, NE PAS entrer.

### Piège 5 : Kill Zone sur Step Index

Step Index est un indice synthétique 24/7. Les kill zones Forex ne s'appliquent pas.

### Piège 6 : SL trop serré ou trop large

La stratégie indique des SL de 4-15 pips typiquement. Un SL de 30+ pips est trop large. Un SL de 2 pips est trop serré et sortira à la moindre fluctuation.

### Piège 7 : SC-ST sautent TOUJOURS

Ne JAMAIS parier que le SC-ST restera intact. Ils sautent TOUJOURS dans la formation. Cela signifie que le SL doit être placé SOUS le Spring/STB, pas sous le SC.

---

## RÉSUMÉ EXÉCUTIF — ORDRE DES CORRECTIONS

| Priorité | Fichier | Action | Impact |
|----------|---------|--------|--------|
| P0-1 | `SMC_BOS_ChoCh.mqh` | Classifier BOS Classique vs Continuation vs Trap | Fondation de tout |
| P0-2 | `SMC_MarketStructure.mqh` | Ajouter `isAdjustment` + `adjustmentTaken` aux swings | Nécessaire pour CE |
| P0-3 | `SMC_ConceptEntry.mqh` | RÉÉCRIRE la détection : adjustment pris → BOS LTF → signature → entrée | Résout le 0 flèches |
| P1-1 | `SMC_CandleTypes.mqh` | Vérifier que les zones S/D viennent de BQA/manipulatrice | Qualité des zones |
| P1-2 | `SMC_Wyckoff.mqh` | Valider séquence complète pour Golden Setup | Éviter faux GS |
| P1-3 | `SMC_Liquidity.mqh` | Intacts comme TP primaire | Targets correctes |
| P2-1 | `SMC_Refinement.mqh` | Raffinage Multi-TF fonctionnel | Polish |
| P2-2 | `RG_SMV_V2.mq5` | Flèches depuis ConceptEntry/Golden valides | Affichage final |
| P2-3 | `RG_SMV_V2.mq5` | Désactiver Kill Zone pour Step Index | Déblocage signals |

---

*Document généré le $(date) — Basé sur l'analyse exhaustive des Modules 1 à 10 de la formation SMC.*
*À transmettre à Cursor pour implémentation.*
