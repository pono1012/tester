import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/portfolio_service.dart';
import '../models/trade_record.dart';

class AnalysisStatsScreen extends StatefulWidget {
  const AnalysisStatsScreen({super.key});

  @override
  State<AnalysisStatsScreen> createState() => _AnalysisStatsScreenState();
}

class _AnalysisStatsScreenState extends State<AnalysisStatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bot = context.watch<PortfolioService>();
    // Filter: Only closed trades (TP or SL)
    final closedTrades = bot.trades
        .where((t) =>
            t.status == TradeStatus.takeProfit ||
            t.status == TradeStatus.stoppedOut)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Deep Dive Analyse"),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: "Übersicht"),
            Tab(text: "Top Kombinationen"),
            Tab(text: "Long Analyse"),
            Tab(text: "Short Analyse"),
          ],
        ),
      ),
      body: closedTrades.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("Keine geschlossenen Trades für eine Analyse vorhanden."),
                  SizedBox(height: 8),
                  Text("Der Bot muss erst einige Trades abschließen.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(closedTrades),
                _buildCombinationsTab(closedTrades),
                _buildSideAnalysisTab(closedTrades, isLong: true),
                _buildSideAnalysisTab(closedTrades, isLong: false),
              ],
            ),
    );
  }

  // --- Tab 1: Overview ---
  Widget _buildOverviewTab(List<TradeRecord> trades) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(trades, title: "Gesamt Performance"),
        const SizedBox(height: 24),

        const Text("Performance nach Entry Score",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildScorePerformanceGrid(trades),

        const SizedBox(height: 24),
        const Text("Performance nach Aktie",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text("Welche Aktien waren am profitabelsten oder unprofitabelsten?",
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        _buildSymbolPerformance(trades),

        const SizedBox(height: 24),
        const Text("Performance nach TimeFrame",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildGroupedList(trades, (t) => t.botTimeFrame?.label ?? "Unbekannt"),

        const SizedBox(height: 24),
        const Text("Performance nach Strategie",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildExpandableGroup("Nach Entry-Strategie", trades, (t) {
           int strat = t.aiAnalysisSnapshot['entryStrategy'] ?? 0;
           if (strat == 0) return "Market (Sofort)";
           if (strat == 1) return "Pullback (Limit)";
           if (strat == 2) return "Breakout (Stop)";
           return "Unbekannt";
        }),
        _buildExpandableGroup("Nach Stop-Loss Methode", trades, (t) {
           final snap = t.aiAnalysisSnapshot;
           int sm = snap['stopMethod'] ?? 2;
           if (sm == 0) return "Donchian";
           if (sm == 1) return "Prozentual (${snap['stopPercent']}%)";
           return "ATR (${snap['atrMult']}x)";
        }),
        _buildExpandableGroup("Nach Take-Profit Methode", trades, (t) {
           final snap = t.aiAnalysisSnapshot;
           int tm = snap['tpMethod'] ?? 0;
           if (tm == 0) return "Risk/Reward";
           if (tm == 1) return "Prozentual";
           return "ATR-Ziel";
        }),

        const SizedBox(height: 24),
        const Text("Performance nach Indikatoren-Status",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildExpandableGroup("Nach Trendstärke (ADX)", trades, (t) {
           double adx = (t.aiAnalysisSnapshot['adx'] as num?)?.toDouble() ?? 0;
           return adx > 25 ? "Starker Trend (>25)" : "Schwacher Trend (<25)";
        }),
        _buildExpandableGroup("Nach RSI-Zone", trades, (t) {
           double rsi = (t.aiAnalysisSnapshot['rsi'] as num?)?.toDouble() ?? 50;
           if (rsi > 70) return "Überkauft (>70)";
           if (rsi < 30) return "Überverkauft (<30)";
           return "Neutral (30-70)";
        }),
        _buildExpandableGroup("Nach Squeeze-Status", trades, (t) {
           bool squeeze = t.aiAnalysisSnapshot['squeeze'] as bool? ?? false;
           return squeeze ? "Squeeze Aktiv" : "Kein Squeeze";
        }),
      ],
    );
  }

  // --- Tab 2: Top Combinations ---
  Widget _buildCombinationsTab(List<TradeRecord> trades) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "Top LONG Kombinationen"),
              Tab(text: "Top SHORT Kombinationen"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCombinationList(trades, isLong: true),
                _buildCombinationList(trades, isLong: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Tab 3 & 4: Specific Side Analysis ---
  Widget _buildSideAnalysisTab(List<TradeRecord> allTrades,
      {required bool isLong}) {
    final sideTrades = allTrades.where((t) {
      bool tIsLong = t.takeProfit1 > t.entryPrice;
      return tIsLong == isLong;
    }).toList();

    if (sideTrades.isEmpty) {
      return Center(
          child: Text(
              "Keine ${isLong ? 'Long' : 'Short'} Trades vorhanden."));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCard(sideTrades,
            title: "${isLong ? 'Long' : 'Short'} Performance"),
        const SizedBox(height: 24),

        // 1. Best Settings
        const Text("Beste Bot-Einstellungen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text("Welche Konfiguration lieferte die besten Ergebnisse?",
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        _buildRankedList(
          sideTrades,
          (t) => _Analyzer.getSettingsLabel(t),
          limit: 5,
        ),

        const SizedBox(height: 24),

        // 2. Best Market Conditions
        const Text("Beste Marktbedingungen",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text("In welchem Marktumfeld (Trend, RSI, etc.) wurde gewonnen?",
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        _buildRankedList(
          sideTrades,
          (t) => _Analyzer.getMarketProfileLabel(t),
          limit: 5,
        ),

      ],
    );
  }

  // --- Combination List Builder ---
  Widget _buildCombinationList(List<TradeRecord> allTrades, {required bool isLong}) {
    final sideTrades = allTrades.where((t) {
      bool tIsLong = t.takeProfit1 > t.entryPrice;
      return tIsLong == isLong;
    }).toList();

    if (sideTrades.isEmpty) {
      return const Center(child: Text("Keine Trades für diese Seite vorhanden."));
    }

    // Group by Settings + Market
    final groups = _Analyzer.groupTrades(sideTrades, (t) {
      return "${_Analyzer.getSettingsLabel(t)}===${_Analyzer.getMarketProfileLabel(t)}";
    });

    // Sort by Profit Factor (descending)
    groups.sort((a, b) => b.profitFactor.compareTo(a.profitFactor));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        // Split key back
        final parts = group.label.split('===');
        final settings = parts[0];
        final market = parts.length > 1 ? parts[1] : "Unbekannt";

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: group.totalPnL >= 0
                      ? Colors.green.withOpacity(0.5)
                      : Colors.red.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Stats
                _buildStatRow(group, showLabel: false),
                const Divider(),
                // Avg Score
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                      "Ø Entry Score: ${group.avgEntryScore.toStringAsFixed(1)}",
                      style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.blueGrey)),
                ),
                // Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCombinationDetailColumn(
                      icon: Icons.tune,
                      title: "Bot-Einstellungen",
                      content: settings.replaceAll(" | ", "\n"),
                    ),
                    const SizedBox(width: 12),
                    _buildCombinationDetailColumn(
                      icon: Icons.insights,
                      title: "Markt-Snapshot",
                      content: market.replaceAll(" | ", "\n"),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCombinationDetailColumn({required IconData icon, required String title, required String content}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              content,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolPerformance(List<TradeRecord> trades) {
    final groups = _Analyzer.groupTrades(trades, (t) => t.symbol);

    // Sort for winners (descending PnL)
    groups.sort((a, b) => b.totalPnL.compareTo(a.totalPnL));
    final topWinners = groups.where((g) => g.totalPnL >= 0).take(5).toList();

    // Sort for losers (ascending PnL)
    groups.sort((a, b) => a.totalPnL.compareTo(b.totalPnL));
    final topLosers = groups.where((g) => g.totalPnL < 0).take(5).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSymbolList("Top 5 Gewinner", topWinners, Colors.green),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSymbolList("Top 5 Verlierer", topLosers, Colors.red),
        ),
      ],
    );
  }

  Widget _buildSymbolList(String title, List<_GroupStats> groups, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          const Card(
              child: ListTile(
                  dense: true,
                  title: Text("Keine Daten",
                      style: TextStyle(color: Colors.grey)))),
        ...groups.map((g) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(g.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle:
                    Text("${g.count} Trades, ${g.winRate.toStringAsFixed(0)}% WR"),
                trailing: Text(
                  "${g.totalPnL.toStringAsFixed(2)}€",
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            )),
      ],
    );
  }

  // --- Helper Widgets ---

  Widget _buildSummaryCard(List<TradeRecord> trades, {String? title}) {
    final stats = _Analyzer.calculateStats(trades);
    return Card(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (title != null) ...[
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem("Trades", "${stats.count}"),
                _statItem("Win Rate", "${stats.winRate.toStringAsFixed(1)}%"),
                _statItem(
                    "Profit Factor", stats.profitFactor.toStringAsFixed(2)),
                _statItem("Total PnL", "${stats.totalPnL.toStringAsFixed(2)}€",
                    color: stats.totalPnL >= 0 ? Colors.green : Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String val, {Color? color}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(val,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildGroupedList(
      List<TradeRecord> trades, String Function(TradeRecord) grouper) {
    final groups = _Analyzer.groupTrades(trades, grouper);
    // Sort by PnL
    groups.sort((a, b) => b.totalPnL.compareTo(a.totalPnL));

    return Column(
      children: groups.map((g) => _buildStatRow(g)).toList(),
    );
  }

  Widget _buildScorePerformanceGrid(List<TradeRecord> trades) {
    final groups = _Analyzer.groupTrades(trades, (t) {
      // Group in 5er Schritten
      final scoreStep = (t.entryScore / 5).floor() * 5;
      return "$scoreStep";
    });

    // Sort by score ascending
    groups.sort((a, b) {
      final scoreA = int.tryParse(a.label.split(' ')[0]) ?? 0;
      final scoreB = int.tryParse(b.label.split(' ')[0]) ?? 0;
      return scoreA.compareTo(scoreB);
    });

    if (groups.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: groups.map((g) {
            final color = g.totalPnL > 0
                ? Colors.green
                : (g.totalPnL < 0 ? Colors.red : Colors.grey);
            return Container(
              width: 160,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: color.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(8),
                color: color.withOpacity(0.1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Score ${g.label}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const Divider(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${g.count} Trades",
                          style: const TextStyle(fontSize: 11)),
                      Text("${g.winRate.toStringAsFixed(0)}% WR",
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${g.totalPnL >= 0 ? '+' : ''}${g.totalPnL.toStringAsFixed(2)}€",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 14),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRankedList(
      List<TradeRecord> trades, String Function(TradeRecord) grouper,
      {int limit = 5}) {
    final groups = _Analyzer.groupTrades(trades, grouper);
    // Filter out groups with < 2 trades to avoid noise
    final relevant = groups.where((g) => g.count >= 2).toList();

    // Sort by Profit Factor
    relevant.sort((a, b) => b.profitFactor.compareTo(a.profitFactor));

    final top = relevant.take(limit).toList();

    if (top.isEmpty)
      return const Text(
          "Zu wenig Daten für ein Ranking (min. 2 Trades pro Gruppe).",
          style: TextStyle(color: Colors.grey));

    return Column(
      children: top
          .map((g) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.label,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              "Profit Factor: ${g.profitFactor.toStringAsFixed(2)}",
                              style: const TextStyle(color: Colors.blue)),
                          Text("WR: ${g.winRate.toStringAsFixed(0)}%"),
                          Text("${g.totalPnL.toStringAsFixed(2)}€",
                              style: TextStyle(
                                  color: g.totalPnL >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildExpandableGroup(
      String title, List<TradeRecord> trades, String Function(TradeRecord) grouper) {
    final groups = _Analyzer.groupTrades(trades, grouper);
    groups.sort((a, b) => b.totalPnL.compareTo(a.totalPnL));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        children: groups.map((g) => _buildStatRow(g)).toList(),
      ),
    );
  }

  Widget _buildStatRow(_GroupStats g, {bool showLabel = true}) {
    return ListTile(
      dense: true,
      title: showLabel ? Text(g.label) : null,
      subtitle: Text(
          "${g.count} Trades | WR: ${g.winRate.toStringAsFixed(0)}% | PF: ${g.profitFactor.toStringAsFixed(2)}"),
      trailing: Text(
        "${g.totalPnL >= 0 ? '+' : ''}${g.totalPnL.toStringAsFixed(2)}€",
        style: TextStyle(
            color: g.totalPnL >= 0 ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

// --- Logic Helpers ---

class _GroupStats {
  final String label;
  final int count;
  final double totalPnL;
  final int wins;
  final double avgEntryScore;

  // Calculated
  double get winRate => count == 0 ? 0 : (wins / count) * 100;

  final double grossProfit;
  final double grossLoss;

  double get profitFactor {
    if (grossLoss == 0)
      return grossProfit > 0 ? 99.0 : 0.0; // Cap at 99 for "no losses"
    return grossProfit / grossLoss;
  }

  _GroupStats({
    required this.label,
    required this.count,
    required this.totalPnL,
    required this.wins,
    required this.grossProfit,
    required this.grossLoss,
    required this.avgEntryScore,
  });
}

class _Analyzer {
  static _GroupStats calculateStats(List<TradeRecord> trades) {
    double pnl = 0;
    int wins = 0;
    double gP = 0;
    double gL = 0;
    double totalScore = 0;

    for (var t in trades) {
      pnl += t.realizedPnL;
      totalScore += t.entryScore;
      if (t.realizedPnL > 0) {
        wins++;
        gP += t.realizedPnL;
      } else {
        gL += t.realizedPnL.abs();
      }
    }

    return _GroupStats(
      label: "Total",
      count: trades.length,
      totalPnL: pnl,
      wins: wins,
      grossProfit: gP,
      grossLoss: gL,
      avgEntryScore: trades.isEmpty ? 0 : totalScore / trades.length,
    );
  }

  static List<_GroupStats> groupTrades(
      List<TradeRecord> trades, String Function(TradeRecord) grouper) {
    final Map<String, List<TradeRecord>> buckets = {};
    for (var t in trades) {
      final key = grouper(t);
      buckets.putIfAbsent(key, () => []).add(t);
    }

    return buckets.entries.map((e) {
      final stats = calculateStats(e.value);
      return _GroupStats(
        label: e.key,
        count: stats.count,
        totalPnL: stats.totalPnL,
        wins: stats.wins,
        grossProfit: stats.grossProfit,
        grossLoss: stats.grossLoss,
        avgEntryScore: stats.avgEntryScore,
      );
    }).toList();
  }

  static String getSettingsLabel(TradeRecord t) {
    final snap = t.aiAnalysisSnapshot;

    // Strategy
    int strat = snap['entryStrategy'] ?? 0;
    String sName =
        strat == 0 ? "Market" : (strat == 1 ? "Pullback" : "Breakout");

    // Padding (Only show if NOT Market)
    String padStr = "";
    if (strat != 0) {
      int padType = snap['entryPaddingType'] ?? 0;
      double padVal = (snap['entryPadding'] as num?)?.toDouble() ?? 0.0;
      padStr = padType == 0 ? "Pad: ${padVal}%" : "Pad: ${padVal}x ATR";
    }

    // TimeFrame
    String tf = t.botTimeFrame?.label ?? "D1";

    // Stop
    int stopM = snap['stopMethod'] ?? 2;
    String stopName = "";
    if (stopM == 0)
      stopName = "SL: Donchian";
    else if (stopM == 1)
      stopName = "SL: ${snap['stopPercent']}%";
    else
      stopName = "SL: ${snap['atrMult']}x ATR";

    // TP
    int tpM = snap['tpMethod'] ?? 0;
    String tpName = "";
    if (tpM == 0) {
      tpName = "TP: RR ${snap['rrTp1']}/${snap['rrTp2']}";
    } else if (tpM == 1) {
      tpName = "TP: ${snap['tpPercent1']}%/${snap['tpPercent2']}%";
    } else {
      tpName = "TP: ATR ${snap['rrTp1']}x/${snap['rrTp2']}x";
    }

    // Sell Fraction
    double sellFrac = (snap['tp1SellFraction'] as num?)?.toDouble() ?? 0.5;
    String sellStr = "TP1 Sell: ${(sellFrac * 100).toStringAsFixed(0)}%";

    List<String> parts = [sName, tf, stopName, tpName, sellStr];
    if (padStr.isNotEmpty) parts.insert(1, padStr);

    return parts.join(" | ");
  }

  static String getMarketProfileLabel(TradeRecord t) {
    final snap = t.aiAnalysisSnapshot;

    // Trend
    double adx = (snap['adx'] as num?)?.toDouble() ?? 0;
    bool stBull = snap['stBull'] as bool? ?? false;
    String trend = adx > 25 ? "Starker Trend" : "Range/Schwach";
    String dir = stBull ? "(Bull)" : "(Bear)";

    // Price vs EMA20
    double price = (snap['price'] as num?)?.toDouble() ?? 0;
    double ema20 = (snap['ema20'] as num?)?.toDouble() ?? 0;
    String emaState = price > ema20 ? "Preis > EMA20" : "Preis < EMA20";

    // RSI
    double rsi = (snap['rsi'] as num?)?.toDouble() ?? 50;
    String rsiState = "RSI Neutral";
    if (rsi > 70)
      rsiState = "RSI > 70";
    else if (rsi < 30)
      rsiState = "RSI < 30";
    else if (rsi > 55)
      rsiState = "RSI 55-70";
    else if (rsi < 45) rsiState = "RSI 30-45";

    // MACD
    double macdHist = (snap['macdHist'] as num?)?.toDouble() ?? 0;
    String macdState = macdHist > 0 ? "MACD Positiv" : "MACD Negativ";

    // Volatility
    bool squeeze = snap['squeeze'] as bool? ?? false;

    // Ichimoku
    bool cloudBull = snap['ichimoku_cloud_bull'] as bool? ?? false;
    String cloudState = cloudBull ? "Über Wolke" : "Unter Wolke";

    // Pattern
    String pattern = t.entryPattern;
    if (pattern == "Kein Muster" || pattern.isEmpty) pattern = "";

    List<String> parts = [
      "$trend $dir",
      emaState,
      rsiState,
      macdState,
      cloudState
    ];
    if (squeeze) parts.add("Squeeze Aktiv");
    if (pattern.isNotEmpty) parts.add("Muster: $pattern");

    return parts.join(" | ");
  }
}
