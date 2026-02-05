import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/portfolio_service.dart';
import 'fundamental_analysis_screen.dart';
import 'analysis_settings_dialog.dart'; // Import hinzufügen

class ScoreDetailsScreen extends StatelessWidget {
  final TradeSignal? externalSignal;
  final String? externalSymbol;

  const ScoreDetailsScreen({super.key, this.externalSignal, this.externalSymbol});

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    // Nutze externes Signal (vom Bot/TopMover) falls vorhanden, sonst AppProvider
    final sig = externalSignal ?? appProvider.computedData?.latestSignal;
    final symbol = externalSymbol ?? appProvider.symbol;
    
    // ComputedData ist nur verfügbar, wenn wir über den AppProvider kommen
    final data = externalSignal != null ? null : appProvider.computedData;

    if (sig == null) {
      return const Scaffold(body: Center(child: Text("Keine Daten")));
    }

    final snapshot = sig.indicatorValues ?? {}; // Bot-Analyse-Snapshot verwenden

    // Lade Werte aus dem Snapshot für konsistente Anzeige mit der Bot-Logik
    // Fallbacks auf 'data' nur, wenn data != null (also nicht im TopMover Modus)
    final lastRsi = snapshot['rsi'] as double? ?? 50;
    final lastStBull = snapshot['stBull'] as bool? ?? (data?.stBull.last ?? false);
    final lastPrice = snapshot['price'] as double? ?? (data?.bars.last.close ?? 0.0);
    final lastEma20 = snapshot['ema20'] as double? ?? (data?.ema20.last ?? lastPrice);
    final lastMacdHist = snapshot['macdHist'] as double? ?? (data?.macdHist.last ?? 0);
    final squeeze = snapshot['squeeze'] as bool? ?? (data?.squeezeFlags.last ?? false);
    final lastAdx = snapshot['adx'] as double? ?? (data?.adx.last ?? 0);
    final lastStochK = snapshot['stochK'] as double? ?? (data?.stochK.last ?? 50);
    final lastObv = snapshot['obv'] as double? ?? (data?.obv.last ?? 0);

    // NEU: Erweiterte Analysen aus dem Snapshot laden
    final isCloudBullish = snapshot['ichimoku_cloud_bull'] as bool? ?? false;
    final isCrossBullish = snapshot['ichimoku_cross_bull'] as bool? ?? false;
    final divergenceType = snapshot['divergence'] as String? ?? 'none';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analyse Details"),
        actions: [
          // NEU: Einstellungen Button
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: "Strategie Einstellungen",
            onPressed: () => showDialog(
                context: context, builder: (_) => AnalysisSettingsDialog()),
          ),
          // Feature: Zur Bot Watchlist hinzufügen
          Consumer<PortfolioService>(builder: (context, bot, _) {
            final isInWatchlist = bot.watchListMap.containsKey(symbol);
            return IconButton(
              icon: Icon(isInWatchlist
                  ? Icons.playlist_add_check
                  : Icons.playlist_add),
              tooltip: isInWatchlist
                  ? "Bereits in Bot Watchlist"
                  : "Zur Bot Watchlist hinzufügen",
              onPressed: isInWatchlist
                  ? null
                  : () {
                      bot.addWatchlistSymbol(symbol);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text("$symbol zur Bot-Watchlist hinzugefügt!")));
                    },
            );
          })
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Score Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _getColorForType(sig.type).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _getColorForType(sig.type), width: 2),
            ),
            child: Column(
              children: [
                Text("Trading Score",
                    style: Theme.of(context).textTheme.titleMedium),
                Text("${sig.score}/100",
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: _getColorForType(sig.type))),
                Text(sig.type,
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getColorForType(sig.type))),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Detaillierte Indikatoren Erklärung
          const Text("Indikatoren Analyse:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),

          _buildIndicatorCard(
            context,
            "RSI (Relative Strength Index)",
            lastRsi.toStringAsFixed(1),
            lastRsi < 30
                ? "Überverkauft (Bullish)"
                : (lastRsi > 70 ? "Überkauft (Bearish)" : "Neutral"),
            "Der RSI misst die Geschwindigkeit und Veränderung von Preisbewegungen. Werte über 70 deuten auf eine Überhitzung hin (Verkaufsgefahr), Werte unter 30 auf eine Unterbewertung (Kaufchance).",
            lastRsi < 30
                ? Colors.green
                : (lastRsi > 70 ? Colors.red : Colors.grey),
          ),
          _buildIndicatorCard(
            context,
            "Supertrend",
            lastStBull ? "Grün" : "Rot",
            lastStBull ? "Bullish Trend" : "Bearish Trend",
            "Der Supertrend ist ein trendfolgender Indikator basierend auf der Volatilität (ATR). Er zeigt die aktuelle Hauptrichtung des Marktes an.",
            lastStBull ? Colors.green : Colors.red,
          ),
          _buildIndicatorCard(
            context,
            "EMA 20 (Trendfilter)",
            lastEma20.toStringAsFixed(2),
            lastPrice > lastEma20
                ? "Kurs darüber (Bullish)"
                : "Kurs darunter (Bearish)",
            "Der Exponential Moving Average (20 Perioden) dient als kurzfristiger Trendfilter. Preise über dem EMA20 signalisieren oft Stärke.",
            lastPrice > lastEma20 ? Colors.green : Colors.red,
          ),
          _buildIndicatorCard(
            context,
            "MACD Histogramm",
            lastMacdHist.toStringAsFixed(4),
            lastMacdHist > 0 ? "Positives Momentum" : "Negatives Momentum",
            "Das MACD Histogramm zeigt die Differenz zwischen MACD-Linie und Signallinie. Positive Werte zeigen aufsteigendes Momentum, negative Werte absteigendes.",
            lastMacdHist > 0 ? Colors.green : Colors.red,
          ),

          // Neuer Indikator 1: ADX
          _buildIndicatorCard(
            context,
            "ADX (Trendstärke)",
            lastAdx.toStringAsFixed(1),
            lastAdx > 25 ? "Starker Trend" : "Seitwärtsphase",
            "Der Average Directional Index (ADX) misst die Stärke eines Trends, unabhängig von der Richtung. Werte über 25 deuten auf einen etablierten Trend hin.",
            lastAdx > 25 ? Colors.blue : Colors.grey,
          ),

          // Neuer Indikator 2: Bollinger Position
          if (data != null) // Nur anzeigen, wenn wir volle Daten haben (nicht im Snapshot enthalten)
            _buildIndicatorCard(
              context,
              "Bollinger Position",
              (lastPrice > (data.bbMid.last ?? 0))
                  ? "Obere Hälfte"
                  : "Untere Hälfte",
              "Neutral",
              "Zeigt an, ob sich der Preis eher im oberen (bullishen) oder unteren (bearishen) Bereich der Standardabweichung bewegt.",
              Colors.blueGrey,
            ),

          // Neuer Indikator 3: Stochastic
          _buildIndicatorCard(
            context,
            "Stochastic Oszillator",
            lastStochK.toStringAsFixed(1),
            lastStochK > 80
                ? "Überkauft"
                : (lastStochK < 20 ? "Überverkauft" : "Neutral"),
            "Der Stochastic vergleicht den Schlusskurs mit seiner Preisspanne über eine Periode. Werte über 80 deuten auf Überkauftheit, unter 20 auf Überverkauftheit hin.",
            lastStochK > 80
                ? Colors.red
                : (lastStochK < 20 ? Colors.green : Colors.grey),
          ),

          // Neuer Indikator 4: On-Balance Volume
          _buildIndicatorCard(
            context,
            "On-Balance Volume (OBV)",
            _formatObv(lastObv),
            "Volumen-Momentum",
            "OBV addiert oder subtrahiert das Volumen basierend auf der Preisbewegung. Ein steigender OBV bei steigendem Preis bestätigt den Trend.",
            Colors.teal,
          ),

          // Neuer Indikator 5: Ichimoku
          _buildIndicatorCard(
            context,
            "Ichimoku Analyse",
            isCrossBullish ? "Positives Momentum" : "Negatives Momentum",
            isCloudBullish ? "Bullish Trend" : "Bearish Trend",
            "Die Wolke (Kumo) dient als dynamische Support/Resistance Zone. Der Tenkan/Kijun-Cross ist ein Momentumsignal.",
            isCloudBullish ? Colors.green : Colors.red,
          ),

          // Neuer Indikator 6: Divergenz (nur anzeigen, wenn eine erkannt wurde)
          if (divergenceType != 'none')
            _buildIndicatorCard(
              context,
              "RSI Divergenz",
              divergenceType == 'bullish' ? "Bullish erkannt" : "Bearish erkannt",
              "Starkes Umkehrsignal",
              "Eine Divergenz tritt auf, wenn der Preis eine andere Richtung einschlägt als der RSI-Indikator. Dies ist oft ein starkes Signal für eine bevorstehende Trendumkehr.",
              divergenceType == 'bullish' ? Colors.green : Colors.red,
            ),

          if (squeeze)
            _buildIndicatorCard(
              context,
              "TTM Squeeze",
              "Aktiv",
              "Volatilitäts-Ausbruch steht bevor",
              "Die Bollinger Bands liegen innerhalb der Keltner Channels. Dies deutet auf eine Ruhephase hin, der oft eine explosive Bewegung folgt.",
              Colors.orange,
            ),

          const Divider(),
          const SizedBox(height: 16),

          // Setup Daten
          _buildRow(
              "Entry Preis", sig.entryPrice.toStringAsFixed(2), Colors.blue),
          _buildRow("Stop Loss", sig.stopLoss.toStringAsFixed(2), Colors.red),
          _buildRow(
              "Take Profit 1",
              "${sig.takeProfit1.toStringAsFixed(2)} (+${sig.tp1Percent?.toStringAsFixed(1)}%)",
              Colors.green),
          _buildRow(
              "Take Profit 2",
              "${sig.takeProfit2.toStringAsFixed(2)} (+${sig.tp2Percent?.toStringAsFixed(1)}%)",
              Colors.green),
          const SizedBox(height: 8),
          _buildRow("Risk/Reward (CRV)", sig.riskRewardRatio.toStringAsFixed(2),
              Colors.orange),
        ],
      ),
    );
  }

  String _formatObv(double v) {
    if (v.abs() > 1000000) return "${(v / 1000000).toStringAsFixed(2)}M";
    if (v.abs() > 1000) return "${(v / 1000).toStringAsFixed(1)}k";
    return v.toStringAsFixed(0);
  }

  String _formatLarge(double? v) {
    if (v == null) return "-";
    if (v > 1e9) return "${(v / 1e9).toStringAsFixed(2)} Mrd.";
    if (v > 1e6) return "${(v / 1e6).toStringAsFixed(2)} Mio.";
    return v.toStringAsFixed(0);
  }

  Widget _buildIndicatorCard(BuildContext context, String title, String value,
      String status, String desc, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text("Wert: $value",
                style: const TextStyle(fontFamily: "monospace")),
            const SizedBox(height: 8),
            Text(desc, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Color _getColorForType(String type) {
    if (type.contains("Buy")) return Colors.green;
    if (type.contains("Sell")) return Colors.red;
    return Colors.grey;
  }

  Color _getColorForVal(double? val, double low, double high,
      {bool invert = false}) {
    if (val == null) return Colors.white;
    if (invert) {
      return val < low
          ? Colors.green
          : (val > high ? Colors.red : Colors.orange);
    }
    return val > high ? Colors.green : (val < low ? Colors.red : Colors.orange);
  }

  Widget _buildRow(String label, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(val,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
