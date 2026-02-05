import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../services/portfolio_service.dart';
import '../models/trade_record.dart';
import 'trade_details_screen.dart';
import 'bot_settings_screen.dart';
import 'analysis_stats_screen.dart';
import '../models/models.dart';
import 'top_movers_screen.dart';

class BotDashboardScreen extends StatelessWidget {
  const BotDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        actions: [
          Consumer<PortfolioService>(builder: (context, bot, _) {
            return IconButton(
              icon: bot.isScanning
                  ? const Icon(Icons.pause_circle_filled, color: Colors.orange)
                  : const Icon(Icons.play_arrow),
              onPressed: () {
                if (bot.isScanning) {
                  bot.cancelRoutine();
                } else {
                  bot.runDailyRoutine();
                }
              },
              tooltip: bot.isScanning ? "Scan abbrechen" : "Scan jetzt starten",
            );
          }),
          IconButton(
            icon: const Icon(Icons.trending_up),
            tooltip: "Top Movers Scan",
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const TopMoversScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: "Bot Einstellungen",
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => BotSettingsScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: "Watchlist bearbeiten",
            onPressed: () => _showWatchlistDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: "Portfolio Reset",
            onPressed: () => _confirmReset(context),
          ),
        ],
      ),
      body: Consumer<PortfolioService>(
        builder: (context, bot, child) {
          return Column(
            children: [
              // --- Header Stats ---
              InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AnalysisStatsScreen())),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat(
                          "Investiert",
                          "${bot.totalInvested.toStringAsFixed(2)} €",
                          Colors.blueAccent),
                      _buildStat(
                          "Unreal. PnL",
                          "${bot.totalUnrealizedPnL.toStringAsFixed(2)} €",
                          bot.totalUnrealizedPnL >= 0
                              ? Colors.green
                              : Colors.red),
                      _buildStat(
                          "Realisiert PnL",
                          "${bot.totalRealizedPnL.toStringAsFixed(2)} €",
                          bot.totalRealizedPnL >= 0 ? Colors.green : Colors.red),
                      _buildStat("Trades", "${bot.trades.length}", Colors.white),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  alignment: WrapAlignment.center,
                  children: TimeFrame.values.map((tf) {
                    return ChoiceChip(
                      label: Text(tf.label, style: const TextStyle(fontSize: 12)),
                      selected: bot.botTimeFrame == tf,
                      onSelected: (selected) => bot.setBotTimeFrame(tf),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
              if (bot.scanStatus.isNotEmpty)
                Container(
                  width: double.infinity,
                  color: Colors.blueGrey.withOpacity(0.2),
                  padding: const EdgeInsets.all(4),
                  child: Text(bot.scanStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12)),
                ),

              const Divider(height: 1),

              // --- Trade Liste ---
              Expanded(
                child: bot.trades.isEmpty
                    ? const Center(
                        child: Text(
                            "Keine Trades vorhanden.\nDrücke Play um den Markt zu scannen.",
                            textAlign: TextAlign.center))
                    : ListView.builder(
                        itemCount: bot.trades.length,
                        itemBuilder: (context, index) {
                          // Neueste zuerst
                          final sortedIndex = bot.trades.length - 1 - index;
                          final trade = bot.trades[sortedIndex];
                          return _buildTradeCard(context, trade, bot);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Portfolio zurücksetzen?"),
        content: const Text(
            "Dies löscht ALLE Trades und setzt das investierte Kapital auf 0 zurück. Bist du sicher?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Abbrechen")),
          TextButton(
            onPressed: () {
              context.read<PortfolioService>().resetPortfolio();
              Navigator.pop(ctx);
            },
            child: const Text("Alles Löschen",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showWatchlistDialog(BuildContext context) {
    final bot = context.read<PortfolioService>();
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Bot Watchlist"),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add New
                    Row(
                      children: [
                        Expanded(child: TextField(
                          controller: textCtrl,
                          decoration: const InputDecoration(hintText: "Symbol (z.B. BTC-USD)"),
                          onSubmitted: (val) {
                            if (val.isNotEmpty) {
                              bot.addWatchlistSymbol(val);
                              textCtrl.clear();
                              setState(() {});
                            }
                          },
                        )),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            if (textCtrl.text.isNotEmpty) {
                              bot.addWatchlistSymbol(textCtrl.text);
                              textCtrl.clear();
                              setState(() {});
                            }
                          },
                        )
                      ],
                    ),
                    const Divider(),
                    // Kategorisierte Liste
                    Expanded(
                      child: Consumer<PortfolioService>(
                        builder: (context, bot, _) {
                          final categories = bot.defaultWatchlistByCategory;
                          return ListView(
                            children: categories.entries.map((categoryEntry) {
                              return ExpansionTile(
                                title: Text(categoryEntry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                initiallyExpanded: ["Germany (DAX & MDAX)", "US Tech (Nasdaq)", "Crypto"].contains(categoryEntry.key),
                                children: categoryEntry.value.map((symbol) {
                                  return CheckboxListTile(
                                    dense: true,
                                    title: Text(symbol),
                                    value: bot.watchListMap[symbol] ?? false,
                                    secondary: IconButton(
                                      icon: const Icon(Icons.delete, size: 20, color: Colors.grey),
                                      onPressed: () => bot.removeWatchlistSymbol(symbol),
                                    ),
                                    onChanged: (val) => bot.toggleWatchlistSymbol(symbol, val ?? false),
                                  );
                                }).toList(),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Fertig")),
          ],
        );
      },
    );
  }

  Widget _buildTradeCard(
      BuildContext context, TradeRecord trade, PortfolioService bot) {
    final isOpen = trade.status == TradeStatus.open;
    final isPending = trade.status == TradeStatus.pending;
    final color = isPending
        ? Colors.orange
        : (isOpen
            ? Colors.blue
            : (trade.realizedPnL >= 0 ? Colors.green : Colors.red));

    String statusText = isOpen ? "OPEN" : "CLOSED";
    if (trade.tp1Hit && isOpen) {
      statusText = "OPEN (TP1 Hit)";
    } else if (isPending) {
      // Prüfen ob Stop (Breakout) oder Limit (Pullback/Market)
      bool isStop = trade.entryReasons.contains("Breakout");
      if (trade.aiAnalysisSnapshot.containsKey('entryStrategy')) {
        if (trade.aiAnalysisSnapshot['entryStrategy'] == 2) isStop = true;
      }
      statusText = isStop ? "PENDING (Stop)" : "PENDING (Limit)";
    }

    return Dismissible(
      key: Key(trade.id),
      direction: DismissDirection.endToStart,
      background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (_) => bot.deleteTrade(trade.id),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TradeDetailsScreen(trade: trade))),
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.2),
            child: Text(trade.symbol.substring(0, min(3, trade.symbol.length)),
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(trade.symbol,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(statusText,
                  style: TextStyle(
                      fontSize: 10,
                      color: isPending
                          ? Colors.orange
                          : (isOpen ? Colors.blue : Colors.grey))),
            ],
          ),
          isThreeLine: true,
          // Zeige Score und Pattern aus der Historie
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(children: [
                Text("Entry: ${trade.entryPrice.toStringAsFixed(2)}"),
                const SizedBox(width: 12),
                if (!isOpen && !isPending)
                  Text("Exit: ${trade.exitPrice?.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              Text(
                  "TP: ${trade.takeProfit1.toStringAsFixed(2)} | SL: ${trade.stopLoss.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                  "Invest: ${(trade.entryPrice * trade.quantity).toStringAsFixed(2)}€ | Score: ${trade.entryScore}",
                  style: TextStyle(
                      fontSize: 10,
                      color: trade.entryScore >= 80
                          ? Colors.greenAccent
                          : Colors.white70)),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isOpen && !isPending)
                Text(
                    "${trade.realizedPnL > 0 ? '+' : ''}${trade.realizedPnL.toStringAsFixed(2)} €",
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              if (isOpen || isPending) ...[
                // Live PnL Anzeige
                Builder(builder: (context) {
                  final currentPrice = trade.lastPrice ?? trade.entryPrice;
                  final pnl = trade.calcUnrealizedPnL(currentPrice);
                  final pct = trade.calcUnrealizedPercent(currentPrice);
                  final pnlColor = pnl >= 0 ? Colors.green : Colors.red;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("${pnl > 0 ? '+' : ''}${pnl.toStringAsFixed(2)} €",
                          style: TextStyle(
                              color: pnlColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text("${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)} %",
                          style: TextStyle(color: pnlColor, fontSize: 12)),
                    ],
                  );
                })
              ]
            ],
          ),
        ),
      ),
    );
  }
}
