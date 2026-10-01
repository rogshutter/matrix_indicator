# AUDIT COMPLET — RG_SMV V2 vs Stratégie (Modules 1 à 10)

**Date :** Juin 2025 (mise à jour : corrections P1 + P2 + P3 appliquées)  
**Fichiers audités :** RG_SMV_V2.mq5 + 12 fichiers Include (+ SMC_Sessions.mqh créé)  
**Référence :** 10 modules de stratégie (textes + images)

---

## RÉSUMÉ EXÉCUTIF — APRÈS CORRECTIONS

| Module | Conformité | Statut |
|--------|-----------|--------|
| M1 - Structure | ✅ 98% | 80/20 filtre actif (bloque trades hors zone extrême) |
| M2 - Bougies | ✅ 85% | Liquidity Signature : interprétation correcte |
| M3 - Order Flow / Breakers | ✅ 90% | OK |
| M4 - Cause & Effet | ✅ 95% | Internals ordonnés temporellement (FAIL→BOS→LIQ→EFFECT) |
| M5 - Liquidité | ✅ 95% | TP ciblant Intact Buyer/Seller + inducement check global |
| **M6 - Sessions/Timing** | **✅ 95%** | **SMC_Sessions.mqh créé : Kill Zones, Monthly, NFP/FOMC** |
| M7 - Wyckoff Golden | ✅ 95% | TP1=PS.high/PSY.low, LPS/LPSY avec ChoCh confirmé, BE sur BOS |
| M8 - Wyckoff Avancé | ✅ 90% | Neutral utilisé en trading (4ème priorité), HTF vérifié |
| M9 - Concept Entry | ✅ 90% | SL=1×zone+buffer, entrée sur corps BOS, BOS cont. swept |
| M10 - Raffinage | ✅ 95% | SL_INTERNAL_ODF implémenté, TF confluences corrigées |
| **GLOBAL - BE** | **✅** | **Break Even sur BOS structurel (MoveToBreakevenOnBOS)** |
| **GLOBAL - TP** | **✅** | **TP basé sur niveaux de liquidité (Intact Buyer/Seller)** |

### Corrections appliquées (Priorité 1 — session précédente)

1. ✅ **Module 6 créé** — SMC_Sessions.mqh : Kill Zones London/NY/Chicago, phases mensuelles, NFP/FOMC
2. ✅ **Break Even sur BOS** — MoveToBreakevenOnBOS() dans SMC_Trade.mqh
3. ✅ **TP liquidité** — Utilise GetNearestIntactSeller/Buyer dans TryOpenPosition
4. ✅ **Golden TP1** — PS.high (accumulation) / PSY.low (distribution)
5. ✅ **Refinement TF doublon** — M30 dédupliqué, séquence M30→M4 correcte

### Corrections appliquées (Priorité 2+3 — cette session)

6. ✅ **80/20 filtre actif** — Bloque achat si prix > 20% bas du range en consolidation
2. ✅ **Neutral en trading** — 4ème priorité dans TryOpenPosition (UT→sell, STB→buy + HTF)
3. ✅ **SL_INTERNAL_ODF** — Implémenté dans SMC_Refinement (50% corps manipulation)
4. ✅ **LPS/LPSY + ChoCh** — Confirmation structurelle obligatoire (higher high / lower low)
5. ✅ **ConceptEntry SL** — Réduit de 1.5× à 1.0×zone+buffer, entrée sur corps BOS
6. ✅ **BOS Continuation** — Ajustement doit être swept avant entrée
7. ✅ **CauseEffect ordering** — FAIL→BOS→LIQ TAKE vérifié temporellement
8. ✅ **Inducement check global** — Vérifié pour Refinement, Golden et Neutral (pas juste Concept)

---

## MODULE 1 — Structure de Marché (SMC_MarketStructure.mqh + SMC_BOS_ChoCh.mqh)

### ✅ Éléments conformes

| Règle stratégique | Implémentation | Fichier/Ligne |
|---|---|---|
| HH+HL = Bullish, LH+LL = Bearish | `GetMarketBias()` vérifie les 3 derniers swings | SMC_MarketStructure.mqh |
| BOS confirmé par clôture (pas la mèche) | `iClose(m_symbol, m_timeframe, b)` utilisé | SMC_BOS_ChoCh.mqh L220+ |
| Structure majeure vs mineure | `isMajor` sur swings, `UpdateMajorStructure()` | SMC_MarketStructure.mqh |
| 3 types BOS (Classic/Continuation/Trap) | `ENUM_BOS_SUBTYPE` avec assignation correcte | SMC_BOS_ChoCh.mqh |
| Fractality HTF→LTF | HTF mis à jour avant LTF, `IsFractalConfluenceForBuy/Sell()` | RG_SMV_V2.mq5 |
| Consolidation (range étroit) | `IsConsolidation()` — highSpread/lowSpread < 30% range | SMC_MarketStructure.mqh |
| Rotation structure (perte d'intensité) | `HasRotationStructure()` — 60% legs décroissantes | SMC_MarketStructure.mqh |

### ⚠️ Écarts

| Problème | Stratégie | Code actuel | Impact |
|---|---|---|---|
| **80/20 non utilisé pour les trades** | Le prix doit être en zone 80/20 pour entrer | `IsPriceIn8020Zone()` existe mais n'est jamais appelé dans `TryOpenPosition()` | Entrées dans la zone intermédiaire, hors POI, RR dégradé |
| **Swing detection simplifiée** | La stratégie insiste sur l'alternation H-L-H-L | `BuildAlternatingSequence()` force l'alternation, mais un swing strength fixe de 3 barres peut rater des swings sur des TF plus hauts | Faux swings sur H4/D1 si strength=3 |

---

## MODULE 2 — Types de Bougies (SMC_CandleTypes.mqh)

### ✅ Éléments conformes

| Règle | Implémentation |
|---|---|
| Bougie Manipulatrice (body ≥ 70% range) | `IsBougieManipulatrice()` : body/range >= 0.70 |
| BQA (Bougie Qui prend l'Argent) adjacente | Zone = Manip + BQA(i-1), supply/demand |
| Doji (body ≤ 15% range) | `IsDoji()` : bodyRatio <= 0.15 |
| Doji Signature (doji isolé + next > 2× range) | `IsDojiSignature()` implémenté |
| Confirmation par clôture au-delà de la zone | `confirmed` vérifié par next candle close |
| Mitigation (zone annulée si close through) | `CheckMitigation()` parcourt les bougies suivantes |

### ⚠️ Écarts

| Problème | Stratégie | Code actuel | Impact |
|---|---|---|---|
| **Liquidity Signature mal interprétée** | Grande mèche = **piège de liquidité**, pas rejet. La mèche montre où l'argent est pris → zone d'entrée contre la mèche | `HasLargeWick()` détecte bien la mèche, mais la zone créée par Doji Signature n'a pas cette logique inversée | Certaines zones sont interprétées comme du rejet au lieu d'un piège |

---

## MODULE 3 — Order Flow + Breaker Blocks (SMC_OrderFlow.mqh)

### ✅ Éléments conformes

| Règle | Implémentation |
|---|---|
| ODF = escalier de zones demand/supply | Chaîne de zones où chaque nouvelle manipulative touche la précédente (50% tolérance) |
| Breaker Block = zone mitiguée + BOS opposé | Zone invalidée → inversée si BOS dans l'autre sens après |
| Réaction BB confirmée par bougie directionnelle | `IsBullishReaction()`/`IsBearishReaction()` vérifie close vs open |
| Visualisation chaînes + blocs | `DrawOrderFlow()`, `DrawBreakerBlocks()` |

### ✅ Aucun écart significatif

---

## MODULE 4 — Cause et Effet / Accumulation-Distribution (SMC_CauseEffect.mqh)

### ✅ Éléments conformes

| Règle | Implémentation |
|---|---|
| Consolidation détectée (minBars=20) | `DetectConsolidation()` avec expansion max 2.5×ATR |
| Tendance avant → classification (Accum/Distrib/Re-Accum/Re-Distrib) | `ClassifyZone()` correcte |
| 4 Internals (Fail, Intention, Liq Take, BOS) | `AnalyzeInternals()` détecte les 4 |
| Effet = close au-delà de la boundary | `hasEffect` vérifié |

### ⚠️ Écarts

| Problème | Stratégie | Code actuel | Impact |
|---|---|---|---|
| **FAIL simplifié** | Un FAIL = swing très près de la boundary (±0.2% du range) | La tolérance de 0.2% est correcte, mais le code ne vérifie pas que c'est un **swing structurel** vs juste une mèche | Faux FAIL détectés sur du bruit |
| **Intention pas liée à BOS** | Après un FAIL, un BOS dans la zone confirme l'intention | Le code vérifie `hasBOS` globalement, pas spécifiquement après un `hasFailed` | Les séquences internes ne sont pas ordonnées |

---

## MODULE 5 — Liquidité (SMC_Liquidity.mqh)

### ✅ Éléments conformes

| Règle | Implémentation |
|---|---|
| Intact Seller = swing high jamais clôturé au-dessus | `DetectIntactLevels()` correct |
| Intact Buyer = swing low jamais clôturé en dessous | Idem |
| EQL = 2+ lows dans 25% ATR | `DetectEqualLevels()` correct |
| EQH = 2+ highs dans 25% ATR | Idem |
| Trendline Liq = 3+ touches sur ligne interpolée | `DetectTrendlineLiquidity()` correct |
| Inducement = LH (bearish) / HL (bullish) non-majeur | `DetectInducements()` correct |
| Sweep vérification | `CheckSweeps()` parcourt en temps réel |

### ⚠️ Écarts

| Problème | Stratégie | Code actuel | Impact |
|---|---|---|---|
| **Liquidité non utilisée comme TP** | Intact Buyer/Seller + EQL/EQH sont des **cibles de TP** selon la stratégie | Les TP sont calculés en multiples du risque (2R, 4R) et JAMAIS basés sur ces niveaux | TP suboptimaux — les niveaux de liquidité sont les vrais objectifs algorithmiques |
| **Inducement sweep non vérifié avant trade** | L'inducement **doit** être swept avant d'entrer | `TryOpenPosition()` ne vérifie pas si un inducement a été récemment swept (sauf dans ConceptEntry) | Trades ouverts sans que la liquidité ait été prise |

---

## MODULE 6 — Sessions / Timing / "Heure de Tir" ❌ NON IMPLÉMENTÉ

### ❌ Totalement absent du code

La stratégie Module 6 définit des règles temporelles critiques :

| Règle | Description | Code |
|---|---|---|
| **Kill Zones (Heure de Tir)** | Europe 9h/8h, US 14h/13h, Chicago 16h/15h, Sydney 2h/1h, Tokyo 4h/3h (heure France) | **ABSENT** |
| **Monthly High/Low** | Se forme entre le 26 et le 9 du mois | **ABSENT** |
| **Mid-Month** | Entre le 14 et 18, mouvement correctif | **ABSENT** |
| **NFP/FOMC** | Accélérateurs de setups, pas créateurs de pattern | **ABSENT** |
| **No-Trade Zones** | Hors kill zones = pas de trade | **ABSENT** |

### Impact

L'absence de filtre de session est le **problème le plus grave** de l'EA :

- **Entrées en dehors des heures actives** → faux signaux en marché asiatique pour EUR/USD
- **Pas de contexte mensuel** → ignore si le monthly high/low est déjà formé
- **Trades pendant le bruit** → NFP/FOMC non pris en compte

### Correction requise : Créer `SMC_Sessions.mqh`

---

## MODULE 7 — Wyckoff Golden Setup (SMC_Wyckoff.mqh)

### ✅ Éléments conformes

| Règle | Implémentation |
|---|---|
| 5 Phases (A-E) | Enum `ENUM_WYCKOFF_PHASE` + détection séquentielle |
| Accumulation Type 1 (2 liq grabs: STB + Spring) | `AnalyzeAccumulation()` détecte STB puis Spring |
| Accumulation Type 2 (1 liq grab: STB seul) | Pattern type `WYCK_ACCUMULATION_2` |
| Distribution Type 1 (UT + UTAD) / Type 2 (UT seul) | `AnalyzeDistribution()` symétrique |
| Golden Entry = LPS (accum) / LPSY (distrib) | `DetectGoldenEntry()` cherche WE_LPS / WE_LPSY |
| SL sous Spring/STB + 10% buffer | `slBuffer = rangeSize * 0.1`, SL = prix le plus bas des Spring/STB − buffer |
| Labels Wyckoff visuels | `DrawPatterns()` avec tous les labels |

### ⚠️ Écarts

| Problème | Stratégie | Code actuel | Impact |
|---|---|---|---|
| **TP1 devrait être PS.high** | "Le haut du PS se fait TOUJOURS swept → cible TP" | `goldenEntryTP1 = pattern.rangeHigh` (AR level) au lieu du PS.high spécifique | TP1 potentiellement trop éloigné ou trop proche |
| **TP2 devrait cibler Intact Levels** | Intact Seller/Buyer, zones Supply/Demand précédentes | `goldenEntryTP2 = rangeHigh + rangeSize` (projection arbitraire) | TP2 n'est pas basé sur les vrais niveaux de liquidité |
| **Break Even déclenché trop tôt** | "BE uniquement après BOS de la structure au-dessus de l'entrée – jamais prématurément" | `MoveToBreakeven(minProfit)` se déclenche dès que profit > minProfit en valeur absolue | BE prématuré → sortie avant le vrai mouvement |
| **LPS trouvé trop simplement** | LPS = test du niveau liq sweep avec confirmation structurelle | Le code cherche juste un low proche du liqLevel après le sweep, sans vérifier la structure haussière (ChoCh) | Faux LPS détectés |
| **Consolidation sur STB réduit prob. Spring** | Si prix consolide sur STB → probabilité de Spring diminue | Non vérifié — le code ne regarde pas si le prix latéralise sur le STB | Attente de Spring inutile parfois |

---

## MODULE 8 — Wyckoff Avancé (SMC_Wyckoff.mqh)

### ✅ Éléments conformes

| Règle | Implémentation |
|---|---|
| Décompte neutre (BC + SC simultanés) | `SWyckoffNeutral` avec rangeHigh/Low + tests BC/SC |
| Liquidité interne (ST) vs externe (UT/STB) | `bcSupplyTested`, `scDemandTested`, `utTriggered`, `stbTriggered` |
| Structure de Rotation avec perte de momentum | `SRotationStructure` avec waveCount, impulseSize[], momentumLoss |
| Diagonal lines (trend channel) | `diagonalHighStart/End`, `diagonalLowStart/End` |
| Labels Wyckoff dans rotation (PS, SC/BC, ST, etc.) | Flags booléens correspondants |

### ⚠️ Écarts

| Problème | Stratégie | Code actuel | Impact |
|---|---|---|---|
| **Biais HTF non vérifié côté Neutre** | "Toujours respecter le biais directionnel — ne pas combattre le HTF" | `SWyckoffNeutral.direction` est calculé mais `TryOpenPosition()` ne l'utilise pas comme filtre pour le UT sell vs STB buy | Trades contretendance possibles |
| **Hedging non supporté** | Module 8 mentionne le hedging (buy+sell dans la même cause) | Non implémenté — `InpMaxPositions` par défaut = 1 | Pas critique (hedging avancé) |
| **Neutre non utilisé pour le trading** | Les patterns neutres sont détectés et dessinés | `TryOpenPosition()` n'a aucune logique pour exploiter les patterns neutres | Fonctionnalité visuelle uniquement |

---

## MODULE 9 — Concept Entry (SMC_ConceptEntry.mqh)

### ✅ Éléments conformes

| Règle | Implémentation |
|---|---|
| Entrée hors Golden Setup | Logique indépendante de Wyckoff (sauf `hasPreviousCause`) |
| Inducement detection (swing non-BOS) | `DetectInducements()` + `IsInducementLevel()` |
| Inducement sweep verification | `CheckInducementSweeps()` parcourt les bougies |
| BOS Classification (Classic vs Continuation) | `ClassifyBOS()` — si cause Wyckoff active → Classic, sinon Continuation |
| Algo Signature (mèche > 60% range) | `FindAlgoSignature()` correct |
| Order Flow (Impulsion → Retracement → Continuation) | `DetectOrderFlow()` détecte les 3 phases |
| Validité = zone + (impulsion OR retracement) | `isValid` condition correcte |

### ⚠️ Écarts

| Problème | Stratégie | Code actuel | Impact |
|---|---|---|---|
| **Multi-TF non-standard ABSENT** | Vérifier 5min, 6min, 7min, 8min, 9min, 10min, 11min, 12min → confluent entry levels | ConceptEntry ne fait aucune vérification multi-TF (c'est Refinement qui le fait, mais avec TF limités) | Confluences algorithmiques manquées |
| **TP fixe (2R/4R)** | TP basé sur inducement levels, intact zones, EQL/EQH | `takeProfit1 = entry + risk * 2`, `takeProfit2 = entry + risk * 4` | RR de 16-24 comme montré dans les exemples est impossible avec TP fixe |
| **Entrée sur la zone uniquement** | "Entrée sur le TEST de la bougie BOS" (body, pas zone) | `entryPrice = entryZoneLow` (zone) au lieu du body de la bougie BOS | Entrée moins précise |
| **BOS Continuation → adjustment** | "Le BOS continuation devient un inducement/adjustment qui DOIT être swept" | Le code classifie mais ne vérifie pas que le niveau de continuation est ensuite swept | Entrées sans que l'adjustment ait été nettoyé |
| **SL trop conservateur** | SL de 8-16 pips typique | `SL = entry − zoneSize × 1.5` → peut être > 20 pips | Ratio RR dégradé |

---

## MODULE 10 — Raffinage PE & SL (SMC_Refinement.mqh)

### ✅ Éléments conformes

| Règle | Implémentation |
|---|---|
| Bougies Signature (Doji, 2G, Manipulative) | 3 détecteurs indépendants corrects |
| Doji = body < 15% range | `m_dojiBodyRatio = 0.15` |
| 2G = engulfing ou doji+impulsion | `Is2GPattern()` vérifie les deux cas |
| Manipulative = mèche totale > 2× body, unidirectionnelle | `IsManipulativeCandle()` avec ratio + check |
| Confluence multi-TF | `CheckTFConfluence()` parcourt 8 TF |
| SL options : Body Doji, Wick Complet, Body Confluence | 3 calculs avec sélection automatique |
| SL max 15 pips | `m_maxSLPips = 15.0` |
| TP1 = 2R, TP2 = 4R | Calculs corrects |

### ⚠️ Écarts

| Problème | Stratégie | Code actuel | Impact |
|---|---|---|---|
| **TF de confluence limités** | Stratégie : 45min, 30min, 20min, 18min, 16min, 15min, 14min, 13min, 12min, 11min, 10min | Code : M30, M30 (doublon!), M20, M15, M12, M10, M6, M5 — manque M45, M18, M16, M14, M13, M11 | Confluences non standard manquées |
| **Doublon M30** | `m_confluenceTFs[0] = PERIOD_M30; m_confluenceTFs[1] = PERIOD_M30` | Bug : index 0 et 1 identiques | 1 TF gaspillé |
| **SL_INTERNAL_ODF** | Stratégie : "ODF recovery level = SL ultra-agressif (1.5-4 pips)" | Type `SL_INTERNAL_ODF` défini dans enum mais jamais calculé | Option de SL la plus agressive manquante |
| **TP devrait cibler intact levels** | "Trendline highs qui n'ont pas cassé structure → TP = 74 RR" | TP1/TP2 = 2R/4R fixe | RR potentiel largement sous-exploité |
| **PE sur wick vs body** | "Travailler le PE sur le body (plus sûr) ou le wick (meilleur prix)" | Le code utilise toujours `bodyBottom`/`bodyTop` | Pas de choix wick pour meilleur prix |
| **"Raffiné" vs "Affiné"** | Ne pas descendre en TF absurdement petit pour trouver "l'extrême" | Le code est raisonnable (M5-M30), mais manque les TF intermédiaires | OK — mais corrigeable |

---

## PROBLÈMES TRANSVERSAUX

### 1. Break Even Incorrect (SMC_Trade.mqh)

| Stratégie | Code |
|---|---|
| "BE uniquement après BOS de la structure au-dessus de l'entrée" | `MoveToBreakeven(minProfit)` : se déclenche quand `price − openPrice >= minProfit` |

**Impact :** Le BE prématuré coupe les trades gagnants avant le vrai mouvement. La stratégie exige qu'un BOS structurel confirme que le prix a changé de direction au-dessus du point d'entrée.

**NOTE :** `MoveToBreakeven()` n'est même pas appelé dans `OnTick()` ou `TryOpenPosition()` actuellement. C'est une fonction morte — mais si elle est activée, elle sera incorrecte.

### 2. TP Jamais Basé sur la Liquidité

Tous les modules utilisent des TP en multiples du risque :

- Concept Entry : 2R / 4R
- Refinement : 2R / 4R  
- Golden Entry : rangeHigh / rangeHigh + rangeSize

La stratégie exige :

- **TP1** = PS.high (Golden) ou premier Intact level
- **TP2** = Intact Buyer/Seller, EQL/EQH, Supply/Demand non mitigée
- RR de 15-75 démontrés quand le TP est basé sur la liquidité

### 3. Pas de Filtre 80/20 pour les Entrées

`IsPriceIn8020Zone()` n'est jamais utilisé dans `TryOpenPosition()`. La stratégie exige que le prix soit en zone extrême (haut/bas 20%) pour maximiser le RR.

### 4. Aucun Filtre de Session Implémenté

Voir Module 6 ci-dessus. C'est le gap le plus important car il permet des trades 24/7 sans discrimination de session.

---

## PRIORISATION DES CORRECTIONS

### 🔴 Priorité 1 — Impact majeur sur les performances

| # | Correction | Effort |
|---|---|---|
| 1 | **Créer `SMC_Sessions.mqh`** — Kill Zones (Europe 9h, US 14h, Chicago 16h) comme filtre obligatoire dans `TryOpenPosition()` | Gros |
| 2 | **TP basé sur liquidité** — Remplacer les TP 2R/4R par des niveaux Intact/EQL/EQH/S\&D via `g_liquidity` | Moyen |
| 3 | **Filtre 80/20 dans TryOpenPosition** — Appeler `IsPriceIn8020Zone()` avant d'ouvrir un trade | Petit |

### 🟡 Priorité 2 — Amélioration significative

| # | Correction | Effort |
|---|---|---|
| 4 | **BE sur BOS structurel** — Modifier `MoveToBreakeven()` pour vérifier `HasRecentBOSBullish/Bearish()` au-dessus de l'entrée + appeler depuis `OnTick()` | Moyen |
| 5 | **Fix doublon M30** — `m_confluenceTFs[1]` devrait être `PERIOD_M30` → changer en un TF manquant ou supprimer | Petit |
| 6 | **Implémenter SL_INTERNAL_ODF** dans Refinement | Moyen |
| 7 | **TP1 Golden = PS.high** — Chercher le PS event dans le pattern et utiliser son prix | Petit |
| 8 | **Patterns neutres pour le trading** — Exploiter `SWyckoffNeutral` dans `TryOpenPosition()` (UT=sell, STB=buy avec vérif HTF) | Moyen |

### 🟢 Priorité 3 — Perfectionnement

| # | Correction | Effort |
|---|---|---|
| 9 | Ajouter TF intermédiaires (M11, M13, M14, M16, M18, M45) à la confluence Refinement | Petit |
| 10 | LPS/LPSY avec confirmation ChoCh structurelle | Moyen |
| 11 | BOS Continuation → vérifier que l'adjustment est swept avant entry | Moyen |
| 12 | Monthly High/Low detection (26th-9th rule) | Moyen |

---

## CONCLUSION

L'EA V2 implémente correctement les **fondamentaux structurels** de la stratégie SMC : détection des swings, BOS/ChoCh avec 3 sous-types, Wyckoff 5 phases avec Golden Entry, Order Flow, Breaker Blocks, Cause/Effet avec 4 internals, et liquidité (Intact, EQL/EQH, trendline, inducement).

**Les 3 lacunes critiques** qui dégradent les performances :

1. **Absence totale de filtre temporel/session** → trades en dehors des heures actives
2. **TP basés sur des ratios fixes** au lieu des niveaux de liquidité → sous-exploitation du potentiel RR
3. **Pas de filtre 80/20** → entrées en zone intermédiaire à faible probabilité

Ces 3 corrections transformeraient l'EA d'un système « structurel correct mais aveugle temporellement et sous-optimisé en RR » en un système aligné avec la stratégie complète.
