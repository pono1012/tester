import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/trade_record.dart';
import '../services/portfolio_service.dart';

class TradeDetailsScreen extends StatelessWidget {
  final TradeRecord trade;

  const TradeDetailsScreen({super.key, required this.trade});

  @override
  Widget build(BuildContext context) {
    final snap = trade.aiAnalysisSnapshot;
    final hasSnap = snap.isNotEmpty;
    final df = DateFormat('dd.MM.yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text("${trade.symbol} Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _confirmDelete(context);
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Header Score ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: (trade.entryScore >= 60 ? Colors.green : Colors.red)
                  .withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: trade.entryScore >= 60 ? Colors.green : Colors.red),
            ),
            child: Column(
              children: [
                const Text("Entry Score", style: TextStyle(fontSize: 16)),
                Text("${trade.entryScore}",
                    style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.bold)),
                if (trade.entryPattern.isNotEmpty)
                  Text("Muster: ${trade.entryPattern}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- Trade Stats ---
          _buildSectionTitle("Trade Daten"),
          _buildInfoRow("Status", _formatStatus(trade)),
          if (trade.botTimeFrame != null)
            _buildInfoRow("Analyse Intervall", trade.botTimeFrame!.label),
          _buildInfoRow("Signal Datum", df.format(trade.entryDate)),
          if (trade.status != TradeStatus.pending && trade.entryExecutionDate != null)
            _buildInfoRow("Ausgeführt am", df.format(trade.entryExecutionDate!)),
          if (trade.executionPrice != null)
            _buildInfoRow("Ausführungskurs", "${trade.executionPrice!.toStringAsFixed(2)}"),
          if (trade.lastScanDate != null)
            _buildInfoRow("Zuletzt geprüft", df.format(trade.lastScanDate!)),
          _buildInfoRow("Entry Preis", "${trade.entryPrice.toStringAsFixed(2)}"),
          _buildInfoRow("Menge", "${trade.quantity.toStringAsFixed(4)}"),
          _buildInfoRow("Investiert",
              "${(trade.entryPrice * trade.quantity).toStringAsFixed(2)} €"),
          const Divider(),
          _buildInfoRow("Stop Loss", "${trade.stopLoss.toStringAsFixed(2)}"),
          _buildInfoRow(
              "Take Profit 1", "${trade.takeProfit1.toStringAsFixed(2)}"),
          _buildInfoRow(
              "Take Profit 2", "${trade.takeProfit2.toStringAsFixed(2)}"),
          if (trade.exitPrice != null) ...[
            const Divider(),
            _buildInfoRow(
                "Exit Preis", "${trade.exitPrice!.toStringAsFixed(2)}"),
            if (trade.closeExecutionDate != null)
              _buildInfoRow("Geschlossen am", df.format(trade.closeExecutionDate!)),
            _buildInfoRow(
                "Realisiert PnL", "${trade.realizedPnL.toStringAsFixed(2)} €",
                color: trade.realizedPnL >= 0 ? Colors.green : Colors.red),
          ],

          const SizedBox(height: 20),

          // --- Indikatoren Snapshot ---
          _buildSectionTitle("Indikatoren zum Kaufzeitpunkt"),
          if (!hasSnap)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("Keine Detail-Daten für diesen Trade gespeichert.",
                  style: TextStyle(color: Colors.grey)),
            )
          else ...[
            _buildIndicatorCard(
              "RSI",
              (snap['rsi'] as num?)?.toStringAsFixed(1) ?? "-",
              _getRsiStatus(snap['rsi'] as num?),
            ),
            _buildIndicatorCard(
              "EMA 20",
              (snap['ema20'] as num?)?.toStringAsFixed(2) ?? "-",
              _getEmaStatus(snap['price'] as num?, snap['ema20'] as num?),
            ),
            _buildIndicatorCard(
              "MACD",
              (snap['macdHist'] as num?)?.toStringAsFixed(4) ?? "-",
              (snap['macdHist'] as num? ?? 0) > 0 ? "Positiv" : "Negativ",
            ),
            _buildIndicatorCard(
              "Supertrend",
              (snap['stBull'] == true) ? "Bullish" : "Bearish",
              "",
            ),
            _buildIndicatorCard(
              "ADX (Trendstärke)",
              (snap['adx'] as num?)?.toStringAsFixed(1) ?? "-",
              ((snap['adx'] as num? ?? 0) > 25) ? "Stark" : "Schwach",
            ),
            _buildIndicatorCard(
              "Squeeze",
              (snap['squeeze'] == true) ? "AKTIV" : "Inaktiv",
              (snap['squeeze'] == true) ? "Volatilität erwartet" : "",
            ),
            // NEU: Ichimoku
            _buildIndicatorCard(
              "Ichimoku",
              (snap['ichimoku_cloud_bull'] == true) ? "Bullish" : "Bearish",
              "Trend: " +
                  ((snap['ichimoku_cloud_bull'] == true)
                      ? "Über Wolke"
                      : "Unter Wolke"),
            ),
            // NEU: Divergenz (nur wenn vorhanden)
            if (snap.containsKey('divergence') && snap['divergence'] != 'none')
              _buildIndicatorCard(
                "Divergenz",
                (snap['divergence'] as String).toUpperCase(),
                "Starkes Umkehrsignal",
              ),
          ],

          const SizedBox(height: 20),

          // --- Bot Settings Snapshot ---
          if (hasSnap && snap.containsKey('entryStrategy')) ...[
            _buildSectionTitle("Verwendete Bot-Strategie"),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _buildCompactSettingRow("Entry Strategie", _getEntryStratName(snap['entryStrategy'])),
                    if (snap['entryStrategy'] != 0)
                      _buildCompactSettingRow("Entry Padding", "${snap['entryPadding']} (${snap['entryPaddingType'] == 0 ? '%' : 'x ATR'})"),
                    const Divider(),
                    _buildCompactSettingRow("Stop Loss Methode", _getStopMethodName(snap['stopMethod'])),
                    if (snap['stopMethod'] == 1) _buildCompactSettingRow("Stop %", "${snap['stopPercent']}%"),
                    if (snap['stopMethod'] == 2) _buildCompactSettingRow("ATR Mult", "${snap['atrMult']}x"),
                    const Divider(),
                    _buildCompactSettingRow("Take Profit Methode", _getTpMethodName(snap['tpMethod'])),
                    _buildCompactSettingRow("TP1", _formatTpVal(snap, 1)),
                    _buildCompactSettingRow("TP2", _formatTpVal(snap, 2)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Trade löschen?"),
        content: const Text(
            "Dieser Trade wird unwiderruflich aus der Historie entfernt."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Abbrechen")),
          TextButton(
            onPressed: () {
              context.read<PortfolioService>().deleteTrade(trade.id);
              Navigator.pop(ctx); // Dialog zu
              Navigator.pop(context); // Screen zu
            },
            child: const Text("Löschen", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCompactSettingRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(val,
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildIndicatorCard(String title, String val, String status) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(status),
        trailing: Text(val,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  String _getRsiStatus(num? rsi) => (rsi ?? 50) < 30
      ? "Überverkauft"
      : ((rsi ?? 50) > 70 ? "Überkauft" : "Neutral");

  String _getEmaStatus(num? price, num? ema) {
    if (price == null || ema == null) return "-";
    return price > ema ? "Kurs > EMA (Bullish)" : "Kurs < EMA (Bearish)";
  }

  String _formatStatus(TradeRecord t) {
    if (t.status == TradeStatus.pending) {
      // 1. Check Snapshot for definitive strategy type
      final snap = t.aiAnalysisSnapshot;
      if (snap.containsKey('entryStrategy')) {
        final strat = snap['entryStrategy'];
        if (strat == 1) return "PENDING (LIMIT / PULLBACK)";
        if (strat == 2) return "PENDING (STOP / BREAKOUT)";
      }
      // 2. Fallback to reasons string
      if (t.entryReasons.contains("Pullback")) return "PENDING (LIMIT / PULLBACK)";
      if (t.entryReasons.contains("Breakout")) return "PENDING (STOP / BREAKOUT)";
      return "PENDING (LIMIT)";
    }
    return t.status.name.toUpperCase();
  }

  String _getEntryStratName(dynamic v) {
    if (v == 1) return "Pullback (Limit)";
    if (v == 2) return "Breakout (Stop)";
    return "Market (Sofort)";
  }

  String _getStopMethodName(dynamic v) {
    if (v == 0) return "Donchian Low";
    if (v == 1) return "Prozentual";
    return "ATR (Volatilität)";
  }

  String _getTpMethodName(dynamic v) {
    if (v == 1) return "Prozentual";
    if (v == 2) return "ATR-Ziel";
    return "Risk/Reward (CRV)";
  }

  String _formatTpVal(Map<String, dynamic> s, int num) {
    int method = s['tpMethod'] ?? 0;
    if (method == 1) {
      return num == 1 ? "${s['tpPercent1']}%" : "${s['tpPercent2']}%";
    } else {
      // RR or ATR
      return num == 1 ? "${s['rrTp1']} R" : "${s['rrTp2']} R";
    }
  }
}
