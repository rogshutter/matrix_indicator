# Rapport d'analyse – Structure du code RG_SMV Version 2

**Projet :** EA Smart Money Concepts (SMC) – Version 2  
**Fichier principal :** `RG_SMV_V2.mq5`  
**Date d'analyse :** 2026

---

## 1. Vue d'ensemble

L’Expert Advisor (EA) **RG_SMV_V2** est une application MQL5 modulaire qui implémente une stratégie **Smart Money Concepts** sur 10 modules pédagogiques (Structure, Bougies, Order Flow, Cause/Effet, Liquidité, Sessions, Wyckoff, Concept Entry, Raffinage PE/SL). Le code est organisé en **un fichier principal** (~1 200 lignes) et **13 fichiers Include** (~8 000 lignes au total).

| Élément | Détail |
|--------|--------|
| **EA principal** | `RG_SMV_V2.mq5` (~1 203 lignes) |
| **Include** | 13 fichiers `SMC_*.mqh` dans `Include/` |
| **Stratégie** | Dossier `Strategie/` (Modules 1–10 : textes + images) |
| **Version** | 2.10 |

---

## 2. Architecture des dépendances

### 2.1 Ordre des includes (EA)

```
SMC_Structures      → types et enums partagés (pas de dépendance interne)
SMC_MarketStructure → Structure de marché (swings, biais)
SMC_BOS_ChoCh       → BOS / ChoCh (dépend de MarketStructure)
SMC_CandleTypes     → Bougies, zones offre/demande
SMC_OrderFlow       → Order Flow, Breaker Blocks
SMC_CauseEffect     → Accumulation / Distribution
SMC_Liquidity       → Liquidité (Intact, EQL/EQH, etc.)
SMC_Wyckoff         → Patterns Wyckoff, Golden Entry
SMC_ConceptEntry    → Concept Entry (inducements, zones)
SMC_Refinement      → Raffinage PE/SL, bougies signature
SMC_Sessions        → Kill Zones, London/NY
SMC_Telegram        → Notifications
SMC_Trade           → Gestion des ordres et risque
```

### 2.2 Graphe de dépendances (Include)

- **Base :** `SMC_Structures.mqh` – utilisé par presque tous les modules.
- **Structure :** `SMC_MarketStructure` → `SMC_BOS_ChoCh` (référence optionnelle HTF pour BOS trap).
- **Chaîne d’analyse :**  
  `MarketStructure` + `BOS_ChoCh` → `OrderFlow`, `CauseEffect`, `Liquidity`, `Wyckoff`, `ConceptEntry`, `Refinement`.
- **ConceptEntry** dépend aussi de **CauseEffect** et **Wyckoff** (cause précédente, type BOS).
- **Trade** ne dépend que de `SMC_Structures` et de la bibliothèque standard `<Trade\Trade.mqh>`.

---

## 3. Fichiers et rôles

### 3.1 Fichier principal : `RG_SMV_V2.mq5`

| Bloc | Rôle |
|------|------|
| **Lignes 1–115** | Includes, paramètres d’entrée (groupes : Timeframes, Structure, Affichage, Module 9/10, Telegram, Sessions, Prise de position). |
| **Lignes 117–155** | Variables globales : pointeurs vers tous les modules, timeframes, drapeaux (initialisation, trading, dernière barre, Telegram, etc.). |
| **Lignes 157–187** | `GetAutoHTF()` – calcul du timeframe supérieur selon le TF du graphique. |
| **Lignes 189–268** | `OnInit()` – création et initialisation des modules (ordre imposé par les dépendances), Telegram, TradeManager, activation trading en backtest. |
| **Lignes 270–288** | `OnDeinit()` – suppression des objets graphiques et libération des modules. |
| **Lignes 290–348** | `OnTick()` – exécution **une fois par nouvelle barre** : mise à jour sessions, `RecalculateAndDraw()` ou mise à jour minimale des modules, diagnostic journalier, Telegram, `TryOpenPosition()`. |
| **Lignes 350–358** | `OnChartEvent()` – redessin lors du changement de zone visible. |
| **Lignes 360–405** | `RecalculateAndDraw()` – calcul des barres à analyser (visible + marge, min 500 LTF / 100 HTF), `Update()` de tous les modules, `DrawVisuals()`. |
| **Lignes 407–567** | `DrawVisuals()` – suppression des objets `SMC_*`, dessin swings, BOS, niveaux clés, Order Flow, Cause/Effet, Liquidité, Wyckoff, Concept Entry, Refinement, flèches signal si mode indicateur. |
| **Lignes 569–624** | `DrawSignalArrows()` – flèches BUY/SELL sur HL/LH (mode sans exécution). |
| **Lignes 720–824** | `CheckTelegramNotifications()` – signaux, Order Blocks, TP touché, SL touché. |
| **Lignes 826–1189** | `TryOpenPosition()` – cœur trading : filtres (Sessions/Kill Zone, BOS trap), fenêtres Concept/Golden adaptées au TF, puis **4 sources de signal** (Refinement → Concept Entry → Golden → Neutral), validation SL/TP, déduplication, TP liquidité, filtre 80/20, exécution (limite ou marché) ou flèche. |
| **Lignes 1191–1216** | `IsFractalConfluenceForBuy()` / `IsFractalConfluenceForSell()` – alignement HTF/LTF pour les confirmations. |

### 3.2 Modules Include (résumé)

| Fichier | Lignes (approx.) | Rôle principal |
|---------|-------------------|----------------|
| **SMC_Structures.mqh** | 330 | Enums (biais, types de swing, BOS, liquidité, etc.), structures (SSwingPoint, SOrderBlock, SFVG, SLiquidityZone, SBreakerBlock, SWyckoffPattern, SConceptEntry, etc.). |
| **SMC_MarketStructure.mqh** | 620 | Détection des swings (HH/HL/LH/LL), structure majeure/mineure, niveaux clés, biais marché, consolidation. |
| **SMC_BOS_ChoCh.mqh** | 398 | Break of Structure / Change of Character, sous-types (classique, continuation, trap), référence HTF pour trap. |
| **SMC_CandleTypes.mqh** | 470 | Types de bougies, zones offre/demande, signatures de liquidité. |
| **SMC_OrderFlow.mqh** | 551 | Order Flow (liens zones), Breaker Blocks. |
| **SMC_CauseEffect.mqh** | 470 | Zones d’accumulation / distribution (cause Wyckoff). |
| **SMC_Liquidity.mqh** | 818 | Niveaux de liquidité (Intact Buyer/Seller, EQL/EQH, Inducement, trendlines), GetNearestIntactSeller/Buyer pour TP. |
| **SMC_Wyckoff.mqh** | 1 874 | Patterns Wyckoff (accumulation/distribution), phases, Golden Entry, patterns neutres, structures de rotation. |
| **SMC_ConceptEntry.mqh** | 807 | Inducements, sweeps, signature algorithmique, zones d’entrée, order flow (impulsion/retracement), calcul PE/SL/TP Concept. |
| **SMC_Refinement.mqh** | 947 | Bougies signature (doji, 2G, manipulatrice), confluence multi-TF, entrées raffinées (PE/SL). |
| **SMC_Sessions.mqh** | 432 | Sessions (London, NY), Kill Zones, `IsTradeAllowed()`. |
| **SMC_Telegram.mqh** | 273 | Envoi de notifications (signaux, OB, TP, SL), credentials fichier si vides. |
| **SMC_Trade.mqh** | 500 | CTradeManager : risque %, drawdown max, max positions, max trades/jour, calcul des lots, PlaceBuy/Sell, PlaceBuyLimit/SellLimit. |

---

## 4. Flux de données et cycle de vie

### 4.1 Démarrage (OnInit)

1. Détermination des TF (auto ou manuels).
2. Création des objets : `CMarketStructure` (Chart + HTF), `CBOSChoCh` (Chart + HTF), puis `CCandleTypes`, `COrderFlow`, `CCauseEffect`, `CLiquidity`, `CWyckoff`, `CConceptEntry`, `CRefinement`, `CSessions`, `CTradeManager`, `CTelegram`.
3. Init dans l’ordre : MS Chart/HTF → BOS HTF puis BOS Chart (avec ref HTF) → Candles → OrderFlow → CauseEffect → Liquidity → Wyckoff → ConceptEntry → Refinement → Sessions → TradeManager → Telegram.
4. Si testeur : `g_tradingEnabled = true`.

### 4.2 Chaque nouvelle barre (OnTick)

1. `g_lastBarTime` évite de retraiter la même barre.
2. `g_sessions.Update()` pour mettre à jour les Kill Zones.
3. **Mode visuel :** `RecalculateAndDraw()` (Update de tous les modules + dessin).  
   **Sans visuel :** Update des modules avec 500/100 barres.
4. Une fois par jour (9h) : diagnostic (HTF/LTF, KillZone, comptages Refinement/Concept/Wyckoff).
5. `CheckTelegramNotifications()` si Telegram activé.
6. `TryOpenPosition()`.

### 4.3 TryOpenPosition – logique de signal

1. **Filtres globaux :**  
   - Sessions / Kill Zone (`g_sessions.IsTradeAllowed()`).  
   - Optionnel : pas de BOS trap récent (`InpRequireNoBOSTrap`).  
   - Fenêtres Concept / Golden adaptées au timeframe (équivalent temps H1).
2. **Sources de signal (priorité) :**  
   - **1. Refinement** – entrée raffinée (confluence, bougie signature), optionnel alignement structure.  
   - **2. Concept Entry** – entrée la plus récente (entryZoneBar), R:R ≥ MinRR, optionnel alignement.  
   - **3. Wyckoff Golden** – accumulation (buy) ou distribution (sell), `barEnd` ≤ goldenMaxBars.  
   - **4. Wyckoff Neutral** – STB (buy) ou UT (sell) avec HTF aligné si demandé.
3. **Validations communes :**  
   - SL/TP du bon côté (buy : SL < entry < TP ; sell : TP < entry < SL).  
   - Déduplication (même signal dans l’heure).  
   - TP éventuellement remplacé par niveau de liquidité (Intact) si meilleur R:R.  
   - R:R ≥ InpMinRR.  
   - Filtre 80/20 en consolidation (prix dans les 20 % extrêmes du range).
4. **Exécution :**  
   - Si `g_tradingEnabled` et `g_tradeManager` : ordre limite ou au marché + log + Telegram.  
   - Sinon : flèche sur le graphique + log (mode indicateur).

---

## 5. Points forts de la structure

- **Modularité :** Chaque concept SMC est isolé dans un fichier dédié, ce qui facilite la maintenance et les évolutions.
- **Dépendances explicites :** L’ordre des includes et des inits reflète les dépendances (Structures → MarketStructure → BOS → … → Trade).
- **Séparation analyse / exécution :** Les modules produisent des signaux (Refinement, ConceptEntry, Wyckoff) ; l’EA centralise les filtres et l’exécution dans `TryOpenPosition()`.
- **Mode double :** Même logique de signal pour le **trading** (ordres) et pour l’**indicateur visuel** (flèches), pilotée par `g_tradingEnabled`.
- **Backtest :** Trading forcé à ON en testeur pour éviter les soucis de paramètres cachés.
- **Fenêtres adaptées au TF :** Concept et Golden utilisent une fenêtre « récente » en temps (équivalent H1) pour M15/M5.

---

## 6. Points d’attention et pistes d’amélioration

| Sujet | Constat | Piste |
|-------|--------|--------|
| **Taille de TryOpenPosition** | ~360 lignes, plusieurs responsabilités (filtres, 4 sources, validations, exécution). | Extraire des fonctions : `GetBestRefinementEntry()`, `GetBestConceptEntry()`, `ApplyCommonValidations()`, `ExecuteOrDrawSignal()`. |
| **Duplication Refinement / Concept** | Validation SL/TP et alignement structure répétés. | Factoriser dans une fonction `ValidateEntry(entry, sl, tp, isBuy, source)`. |
| **SMC_Sessions** | Utilisé uniquement pour le filtre Kill Zone au début de `TryOpenPosition`. | Déjà clair ; éventuellement documenter l’impact (London/NY) dans les inputs. |
| **g_tradingEnabled** | N’est pas vérifié au tout début de `TryOpenPosition()` ; tout le calcul de signal est fait avant. | Acceptable (permet le mode indicateur) ; on pourrait court-circuiter plus tôt si `!g_tradingEnabled` et pas de dessin flèche pour alléger le CPU. |
| **DrawVisuals** | Long, beaucoup de `if(InpDraw*)` et d’appels aux modules. | Possibilité de déléguer par couche (ex. `DrawStructure()`, `DrawModules3To5()`, etc.) pour lisibilité. |
| **Constantes magiques** | Ex. `point * 50`, `point * 30`, `3600` (déduplication). | Remplacer par des constantes nommées ou des inputs (ex. `InpDedupSeconds`). |

---

## 7. Résumé

- **RG_SMV_V2** est un EA SMC structuré en **1 fichier principal** et **13 includes** avec des rôles bien séparés (structure, BOS, bougies, order flow, cause/effet, liquidité, Wyckoff, concept entry, raffinage, sessions, Telegram, trade).
- Le **cycle principal** est **une fois par nouvelle barre** : mise à jour des modules → dessin (si visuel) → notifications Telegram → recherche de signal et exécution (ou flèche).
- La **prise de position** repose sur **4 sources** (Refinement, Concept Entry, Golden, Neutral), avec filtres communs (Sessions, BOS trap, alignement structure optionnel, R:R, 80/20, déduplication) et exécution via **CTradeManager** (risque %, drawdown, limites de positions et de trades/jour).
- La structure est **adaptée à l’évolution** (nouveaux modules, nouveaux filtres) ; les principaux gains possibles concernent le **découpage de TryOpenPosition** et un peu de **factorisation des validations** et du dessin.
