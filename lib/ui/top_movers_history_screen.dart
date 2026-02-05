import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/portfolio_service.dart';

class TopMoversHistoryScreen extends StatefulWidget {
  const TopMoversHistoryScreen({super.key});

  @override
  State<TopMoversHistoryScreen> createState() => _TopMoversHistoryScreenState();
}

class _TopMoversHistoryScreenState extends State<TopMoversHistoryScreen> {
  final DataService _dataService = DataService();
  Map<String, double?> _currentPrices = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentPrices();
  }

  Future<void> _fetchCurrentPrices() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final history = context.read<PortfolioService>().topMoverHistory;
    final allSymbols =
        history.expand((scan) => scan.topMovers.map((m) => m.symbol)).toSet();

    for (final symbol in allSymbols) {
      try {
        final price = await _dataService.fetchRegularMarketPrice(symbol);
        if (mounted) {
          setState(() {
            _currentPrices[symbol] = price;
          });
        }
      } catch (e) {
        debugPrint("Could not fetch price for $symbol: $e");
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<PortfolioService>().topMoverHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Top Movers Historie"),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator())
                : const Icon(Icons.refresh),
            onPressed: _fetchCurrentPrices,
            tooltip: "Aktuelle Kurse laden",
          )
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Text("Keine Scan-Ergebnisse in der Historie vorhanden."))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final scanResult = history[index];
                return _buildScanResultCard(scanResult);
              },
            ),
    );
  }

  Widget _buildScanResultCard(TopMoverScanResult result) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ExpansionTile(
        title: Text(
            "Scan vom ${result.scanDate.day}.${result.scanDate.month}.${result.scanDate.year} ${result.scanDate.hour}:${result.scanDate.minute.toString().padLeft(2, '0')}"),
        subtitle: Text("Intervall: ${result.timeFrame.label}"),
        initiallyExpanded: true,
        children: result.topMovers.map((mover) {
          final currentPrice = _currentPrices[mover.symbol];
          double? change;
          if (currentPrice != null && mover.priceAtScan > 0) {
            change = ((currentPrice - mover.priceAtScan) / mover.priceAtScan) * 100;
          }

          final isBuy = mover.signalType == "Buy";
          final color = isBuy ? Colors.green : Colors.red;
          
          // Wenn es ein Kaufsignal war und der Preis gestiegen ist, ist es gut (grün)
          // Wenn es ein Verkaufssignal war und der Preis gefallen ist, ist es auch gut (grün)
          bool isSuccess = (isBuy && (change ?? 0) > 0) || (!isBuy && (change ?? 0) < 0);

          return ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Text(
                "${mover.score}",
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            title: Text(mover.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Kurs damals: ${mover.priceAtScan.toStringAsFixed(2)}"),
            trailing: change == null
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    "${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%",
                    style: TextStyle(
                      color: isSuccess ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          );
        }).toList(),
      ),
    );
  }
}