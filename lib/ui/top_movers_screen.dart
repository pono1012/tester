import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/trade_record.dart';
import '../providers/app_provider.dart';
import '../services/data_service.dart';
import '../services/portfolio_service.dart';
import 'score_details_screen.dart';
import 'top_movers_history_screen.dart';

class TopMoversScreen extends StatefulWidget {
  const TopMoversScreen({super.key});

  @override
  State<TopMoversScreen> createState() => _TopMoversScreenState();
}

class _TopMover {
  final String symbol;
  final TradeSignal signal;
  _TopMover(this.symbol, this.signal);
}

class _TopMoversScreenState extends State<TopMoversScreen> {
  final DataService _dataService = DataService();
  bool _isLoading = false;
  String _scanStatus = "Bereit zum Scannen.";
  List<_TopMover> _topLong = [];
  List<_TopMover> _topShort = [];
  TimeFrame _selectedTimeFrame = TimeFrame.d1;
  final Map<String, String?> _imageUrls = {};

  Future<void> _runScan() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _scanStatus = "Initialisiere...";
      _topLong = [];
      _topShort = [];
      _imageUrls.clear();
    });

    final portfolioService = context.read<PortfolioService>();
    final activeSymbols = portfolioService.watchListMap.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    List<_TopMover> allSignals = [];
    int count = 0;

    for (final symbol in activeSymbols) {
      count++;
      setState(() {
        _scanStatus = "($count/${activeSymbols.length}) Scanne $symbol...";
      });

      try {
        final bars =
            await _dataService.fetchBars(symbol, interval: _selectedTimeFrame);
        if (bars.length < 50) continue;

        final signal = portfolioService.analyzeStock(bars);
        if (signal != null) {
          allSignals.add(_TopMover(symbol, signal));
        }
        // Kurze Pause um UI reaktiv zu halten
        await Future.delayed(const Duration(milliseconds: 50));
      } catch (e) {
        debugPrint("TopMovers: Fehler bei $symbol: $e");
        continue;
      }
    }

    // Sortieren und Filtern
    allSignals.sort((a, b) => b.signal.score.compareTo(a.signal.score));

    _topLong = allSignals
        .where((s) => s.signal.type.contains("Buy"))
        .take(5)
        .toList();

    // Für Short, sortieren wir aufsteigend nach Score
    allSignals.sort((a, b) => a.signal.score.compareTo(b.signal.score));
    _topShort = allSignals
        .where((s) => s.signal.type.contains("Sell"))
        .take(5)
        .toList();

    setState(() {
      _isLoading = false;
      _scanStatus = "Scan abgeschlossen. ${allSignals.length} Signale gefunden.";
    });

    // Ergebnisse in der Historie speichern
    portfolioService.addTopMoversToHistory(_topLong, _topShort, _selectedTimeFrame);

    // Logos nachladen
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    final symbolsToFetch = {..._topLong.map((e) => e.symbol), ..._topShort.map((e) => e.symbol)};
    if (symbolsToFetch.isEmpty) return;

    final appProvider = context.read<AppProvider>();
    final apiKey = appProvider.settings.fmpKey;
    if (apiKey == null || apiKey.isEmpty) return;

    for (final symbol in symbolsToFetch) {
      try {
        final fmpData = await _dataService.fetchFmpData(symbol, apiKey);
        if (mounted) {
          setState(() {
            _imageUrls[symbol] = fmpData?.image;
          });
        }
      } catch (e) {
        debugPrint("Error fetching image for $symbol: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Top Movers Scan"),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopMoversHistoryScreen())),
            tooltip: "Scan-Historie anzeigen",
          ),
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.radar),
            onPressed: _runScan,
            tooltip: "Scan starten",
          )
        ],
      ),
      body: Column(
        children: [
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
                  selected: _selectedTimeFrame == tf,
                  onSelected: (selected) {
                    if (selected && !_isLoading) {
                      setState(() => _selectedTimeFrame = tf);
                    }
                  },
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.blueGrey.withOpacity(0.2),
            padding: const EdgeInsets.all(8),
            child: Text(_scanStatus, textAlign: TextAlign.center),
          ),
          if (_isLoading && _topLong.isEmpty && _topShort.isEmpty)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  _buildSection("Top 5 Long-Kandidaten", _topLong, Colors.green),
                  _buildSection("Top 5 Short-Kandidaten", _topShort, Colors.red),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<_TopMover> movers, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          if (movers.isEmpty && !_isLoading)
            const Card(
              child: ListTile(
                title: Text("Keine Kandidaten gefunden"),
                subtitle: Text("Passe die Strategie an oder erweitere die Watchlist."),
              ),
            )
          else
            ...movers.map((mover) => _buildMoverCard(mover)),
        ],
      ),
    );
  }

  Widget _buildMoverCard(_TopMover mover) {
    final signal = mover.signal;
    final imageUrl = _imageUrls[mover.symbol];
    final color = signal.type.contains("Buy") ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: () {
          final appProvider = context.read<AppProvider>();
          // Timeframe muss auch gesetzt werden für korrekte Chart-Anzeige
          if (appProvider.selectedTimeFrame != _selectedTimeFrame) {
            appProvider.setTimeFrame(_selectedTimeFrame);
          }
          appProvider.setSymbol(mover.symbol);

          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ScoreDetailsScreen(
                      externalSignal: signal, externalSymbol: mover.symbol)));
        },
        leading: CircleAvatar(
          backgroundColor: imageUrl != null ? Colors.transparent : color.withOpacity(0.2),
          backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
          child: imageUrl == null
              ? Text(
                  "${signal.score}",
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold, fontSize: 18),
                )
              : null,
        ),
        title: Text(mover.symbol,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Pattern: ${signal.chartPattern}\n${signal.reasons.take(2).join(', ')}",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              "Entry: ${signal.entryPrice.toStringAsFixed(2)} | SL: ${signal.stopLoss.toStringAsFixed(2)}\nTP1: ${signal.takeProfit1.toStringAsFixed(2)} (${signal.tp1Percent?.toStringAsFixed(1)}%) | TP2: ${signal.takeProfit2.toStringAsFixed(2)} (${signal.tp2Percent?.toStringAsFixed(1)}%)",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}