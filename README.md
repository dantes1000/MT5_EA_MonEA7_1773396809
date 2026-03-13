```markdown
# MonEA7 - Expert Advisor pour MetaTrader 5

## Description
MonEA7 est un Expert Advisor (EA) avancé pour MetaTrader 5, implémentant une stratégie de **Breakout de Range sur la Session Asiatique**. L'EA identifie des phases de consolidation (range) sur le timeframe D1, calcule des niveaux de cassure clés, et place des ordres en attente pour capturer les mouvements directionnels qui en résultent. La logique intègre de multiples filtres (tendance, volume, volatilité, actualités) et une gestion des risques stricte, conçue pour être compatible avec les exigences des prop firms.

**Stratégie clé :** Range Breakout (Cassure de Range)
- **Période du range :** Session asiatique (00:00 - 06:00 GMT).
- **Niveaux :** High et Low des bougies closes sur D1.
- **Exécution :** Ordres en attente (`Buy Stop`/`Sell Stop`) placés après 08:00 GMT.
- **Confirmation :** Volume et filtres techniques stricts requis.

## Prérequis
- **Plateforme :** MetaTrader 5 (Build 2000 ou supérieur recommandé).
- **Compte :** Compte de trading Forex (CFD) avec accès aux paires majeures.
- **Broker :** Doit fournir les données de volume réel (`VOLUME_TICK` ou `VOLUME_REAL`) pour le filtre de volume.
- **Indicateur :** L'indicateur `FFCal` (Forex Factory Calendar) doit être installé dans le dossier `MQL5\Indicators\` pour le filtre d'actualités.

## Installation
1.  Téléchargez les fichiers de l'EA (`MonEA7.mq5` et les fichiers `.mqh` inclus).
2.  Ouvrez le dossier de données de MetaTrader 5 via `Fichier > Ouvrir le Dossier de Données` dans la plateforme.
3.  Copiez le fichier `MonEA7.mq5` dans le sous-dossier `MQL5\Experts\`.
4.  Copiez tous les fichiers `.mqh` (modules de logique) dans le sous-dossier `MQL5\Include\`.
5.  Redémarrez MetaTrader 5 ou actualisez la liste des Experts Advisors dans le `Navigateur` (clic droit > Rafraîchir).
6.  L'EA `MonEA7` apparaîtra maintenant dans le `Navigateur` sous `Experts Advisors`. Vous pouvez le glisser-déposer sur un graphique.

## Paramètres Configurables

### 1. Breakout / Cassure
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `BreakoutType` | 0 | Type de cassure : `0=Range`, `1=BollingerBands`, `2=ATR`. |
| `AllowLong` | true | Autoriser les positions d'achat (Long). |
| `AllowShort` | true | Autoriser les positions de vente (Short). |
| `RequireVolumeConfirm` | true | Exiger une confirmation du volume pour valider une cassure. |
| `RequireRetest` | false | Attendre un retest du niveau cassé avant d'entrer (désactivé). |
| `RangeTF` | `PERIOD_D1` | Timeframe pour le calcul du range (D1). |
| `TrendFilterEMA` | 200 | Période de l'EMA pour le filtre de tendance globale. `0` pour désactiver. |
| `ExecTF` | `PERIOD_M15` | Timeframe pour l'exécution des trades et la surveillance (M15 ou M30). |

### 2. Filtre News (Actualités Économiques)
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `UseNewsFilter` | true | Activer/désactiver le filtre d'actualités. |
| `NewsMinutesBefore` | 60 | Suspendre le trading X minutes AVANT l'annonce. |
| `NewsMinutesAfter` | 30 | Suspendre le trading X minutes APRÈS l'annonce. |
| `NewsImpactLevel` | 3 | Niveau d'impact minimum à filtrer : `1=Faible`, `2=Moyen`, `3=Fort`. |
| `CloseOnHighImpact` | true | Fermer automatiquement les positions ouvertes avant une news à fort impact. |

### 3. Filtres Indicateurs
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `UseATRFilter` | true | Activer le filtre de volatilité ATR. |
| `ATRPeriod` | 14 | Période de calcul de l'ATR. |
| `MinATRPips` | 20 | Volatilité ATR minimum requise (en pips). |
| `MaxATRPips` | 150 | Volatilité ATR maximum autorisée (en pips). |
| `ATR_Mult_Min` | 1.25 | Multiplicateur ATR minimum pour valider une cassure (prix > ATR*Multi). |
| `UseBBFilter` | true | Activer le filtre de largeur de range (Bollinger Bands). |
| `Min_Width_Pips` | 30 | Largeur minimum des Bandes (en pips) pour valider un range. |
| `Max_Width_Pips` | 120 | Largeur maximum des Bandes (en pips). |
| `UseEMAFilter` | true | Activer le filtre de tendance EMA. |
| `EMAPeriod` | 200 | Période de l'EMA. |
| `EMATf` | `PERIOD_H1` | Timeframe de l'EMA de tendance. |
| `UseADXFilter` | true | Activer le filtre de force de tendance ADX. |
| `ADXThreshold` | 20.0 | Niveau ADX minimum pour considérer une tendance. |
| `UseVolumeFilter` | true | Activer le filtre de confirmation par volume. |
| `VolumeMultiplier` | 1.5 | Le volume doit dépasser la SMA(Volume,20) de ce multiplicateur. |

### 4. Gestion des Positions
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `MagicNumber` | 123456 | Identifiant unique pour tous les ordres de cet EA. |
| `MaxSlippage` | 3 | Slippage maximum toléré (en points). |
| `MaxOrderRetries` | 3 | Nombre de tentatives d'envoi d'un ordre en cas d'échec. |
| `UsePartialClose` | false | Activer la fermeture partielle de position. |
| `AllowAddPosition` | false | Autoriser l'ajout à une position existante si elle est en profit. |

### 5. Gestion des Risques
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `LotMethod` | 0 | Méthode de calcul du lot : `0=% du capital`, `1=Lot fixe`, `2=Lot/pip`. |
| `RiskPercent` | 1.0 | Pourcentage du capital (`Free Margin`) risqué par trade. |
| `MinLot` / `MaxLot` | 0.01 / 5.0 | Lot minimum et maximum autorisé. |
| `StopLossPips` | 0 | Stop Loss fixe en pips. `0` pour le placer à l'opposé du range. |
| `TakeProfitPips` | 0 | Take Profit fixe en pips. `0` pour un TP dynamique basé sur le R:R. |
| `RiskRewardRatio` | 1.5 | Ratio Risque/Récompense cible minimum. |
| `MaxDailyDDPercent` | 5.0 | Drawdown quotidien maximum autorisé (%). |
| `MaxOpenTrades` | 1 | Nombre maximum de positions ouvertes simultanément. |
| `MaxTradesPerDay` | 3 | Nombre maximum de trades par jour. |
| `MinTimeBetweenTrades` | 1 | Délai minimum obligatoire entre deux trades (en heures). |

### 6. Range de Prix
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `RangePeriodHours` | 6 | Durée de la fenêtre pour calculer le range (session asiatique 6h). |
| `MarginPips` | 5 | Marge de sécurité ajoutée au-delà du High/Low pour placer les ordres en attente. |
| `MinRangePips` / `MaxRangePips` | 20 / 120 | Étendue (en pips) minimum et maximum du range pour le valider. |

### 7. Filtres Temporels
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `TradeStartHour` / `TradeEndHour` | 8 / 23 | Fenêtre de trading quotidienne (heures GMT). |
| `TradeMonday` ... `TradeFriday` | true | Jours de la semaine où le trading est autorisé. |
| `WeekendClose` | true | Fermer toutes les positions avant le week-end. |
| `FridayCloseHour` | 21 | Heure de fermeture des positions le vendredi (GMT). |

### 8. Stratégie Tendance & Trailing Stop
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `UseTrailingStop` | true | Activer le trailing stop dynamique. |
| `Trail_Method` | 1 | Méthode : `0=Fixe (pips)`, `1=Basé sur ATR`. |
| `Trail_Mult` | 0.5 | Multiplicateur de l'ATR pour définir la distance du trailing stop. |
| `Trail_Activation_PC` | 50 | Pourcentage de profit réalisé nécessaire pour activer le trailing stop. |

## Utilisation
1.  **Graphique :** Attachez l'EA `MonEA7` sur un graphique H1, M30 ou M15 d'une paire majeure (ex: EURUSD). Le timeframe `ExecTF` défini dans les paramètres sera utilisé pour la surveillance.
2.  **Activation :** Assurez-vous que le `Trading Automatique` est autorisé (bouton "Auto Trading" en haut de MT5) et que les paramètres correspondent à votre profil de risque.
3.  **Fonctionnement :**
    *   Chaque jour, l'EA calcule le **High** et le **Low** de la session asiatique (00:00-06:00 GMT) sur le graphique D1.
    *   Après 08:00 GMT, il place des **ordres en attente** (`Buy Stop` au-dessus du High + marge, `Sell Stop` en dessous du Low - marge).
    *   Si le prix atteint un niveau et que **tous les filtres sont validés** (volume, tendance H1 > EMA200, ADX >20, etc.), l'ordre est exécuté.
    *   Le **Stop Loss** est placé de l'autre côté du range. Le **Take Profit** est calculé dynamiquement (par défaut R:R de 1.5).
    *   Un **trailing stop** basé sur l'ATR peut se déclencher une fois 50% du profit cible atteint.
    *   Le trading est suspendu autour des annonces économiques majeures.
4.  **Monitoring :** Surveillez les logs dans l'onglet `Experts` du Terminal MT5 pour voir les signaux, les placements d'ordres et les actions de l'EA.

## Avertissement sur les Risques
**LE TRADING SUR LE FOREX ET LES MARCHÉS FINANCIERS IMPLIQUE DES RISQUES ÉLEVÉS DE PERTE.** Cet Expert Advisor est un outil logiciel fourni "TEL QUEL", à des fins éducatives et de démonstration.

*   **Aucune garantie de profit** n'est fournie. Les performances passées ne préjugent pas des résultats futurs.
*   **Testez rigoureusement** l'EA en backtest et sur un **compte de démonstration** avant toute utilisation en conditions réelles.
*   **Comprenez parfaitement** la stratégie et tous les paramètres de gestion des risques.
*   **Vous êtes seul responsable** des décisions de trading et des conséquences financières qui en découlent. Il est recommandé de consulter un conseiller financier indépendant.
*   L'EA intègre des mesures de gestion des risques (drawdown max, stop loss). Cependant, des conditions de marché extrêmes (gap, slippage important, volatilité excessive) peuvent entraîner des pertes supérieures aux limites prévues.

**Utilisez cet EA à vos propres risques.**
```