import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/data_service.dart';
import '../models/models.dart';

class FundamentalAnalysisScreen extends StatefulWidget {
  final String symbol;
  final String apiKey;

  const FundamentalAnalysisScreen(
      {super.key, required this.symbol, required this.apiKey});

  @override
  State<FundamentalAnalysisScreen> createState() =>
      _FundamentalAnalysisScreenState();
}

class _FundamentalAnalysisScreenState extends State<FundamentalAnalysisScreen> {
  bool _isLoading = true;
  FmpData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.apiKey.isEmpty) {
      setState(() {
        _error = "Kein FMP API Key in den Einstellungen gefunden.";
        _isLoading = false;
      });
      return;
    }

    final ds = DataService();
    final data = await ds.fetchFmpData(widget.symbol, widget.apiKey);

    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
        if (data == null)
          _error =
              "Konnte Daten für ${widget.symbol} nicht laden (Limit erreicht oder Symbol falsch).";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Fundamentalanalyse: ${widget.symbol}")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : _buildContent(context, _data!),
    );
  }

  Widget _buildContent(BuildContext context, FmpData d) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                if (d.image != null)
                  Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                          image: NetworkImage(d.image!), fit: BoxFit.contain),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Text(d.symbol.substring(0, 1),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent)),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.companyName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("${d.exchange ?? ''} : ${d.symbol}",
                          style: const TextStyle(
                              color: Colors.grey, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                              "${d.price.toStringAsFixed(2)} ${d.currency ?? 'USD'}",
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 12),
                          if (d.changes != null)
                            Text(
                                "${d.changes! >= 0 ? '+' : ''}${d.changes!.toStringAsFixed(2)} (${d.changesPercentage?.toStringAsFixed(2)}%)",
                                style: TextStyle(
                                    color: (d.changes ?? 0) >= 0
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- Company Profile ---
          const Text("Unternehmensprofil",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(d.description,
              style: const TextStyle(color: Colors.grey, height: 1.4)),
          const SizedBox(height: 16),
          _buildInfoGrid([
            _buildInfoItem("CEO", d.ceo),
            _buildInfoItem("Sektor", d.sector),
            _buildInfoItem("Industrie", d.industry),
            _buildInfoItem("Land", d.country),
            _buildInfoItem("Mitarbeiter", d.fullTimeEmployees),
            _buildInfoItem("IPO Datum", d.ipoDate),
            _buildInfoItem("Webseite", d.website, isLink: true),
          ]),
          const SizedBox(height: 24),

          // --- Market Data ---
          const Text("Marktdaten",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildInfoGrid([
            _buildInfoItem("Marktkap.", _formatLarge(d.marketCap)),
            _buildInfoItem("Volumen (Avg)", _formatLarge(d.volAvg ?? 0)),
            _buildInfoItem("Beta (Vola)", d.beta.toStringAsFixed(2)),
            _buildInfoItem("52W Range", d.range),
            _buildInfoItem("Letzte Div.", d.lastDiv?.toStringAsFixed(2)),
            _buildInfoItem("ETF?", d.isEtf ? "Ja" : "Nein"),
          ]),
          const SizedBox(height: 24),

          // Link zu Aktien.guide
          Center(
            child: ElevatedButton.icon(
              onPressed: () async {
                // Symbol bereinigen: Endungen wie .DE oder .DEF entfernen für die Suche
                String searchSym = d.symbol;
                if (searchSym.endsWith(".DE")) {
                  searchSym = searchSym.substring(0, searchSym.length - 3);
                } else if (searchSym.endsWith(".DEF")) {
                  searchSym = searchSym.substring(0, searchSym.length - 4);
                }

                final url =
                    Uri.parse('https://aktien.guide/search?q=$searchSym');
                if (!await launchUrl(url,
                    mode: LaunchMode.externalApplication)) {
                  debugPrint("Konnte $url nicht öffnen");
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text("Mehr Infos auf Aktien.guide"),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
              child: Text("Daten bereitgestellt von Financial Modeling Prep",
                  style: TextStyle(fontSize: 10, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<Widget> children) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: children,
    );
  }

  Widget _buildInfoItem(String label, String? val, {bool isLink = false}) {
    if (val == null || val.isEmpty) return const SizedBox.shrink();
    return Container(
      width: 150, // Fixed width for grid look
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(val,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isLink ? Colors.blueAccent : null)),
        ],
      ),
    );
  }

  String _formatLarge(double val) {
    if (val > 1e12) return "${(val / 1e12).toStringAsFixed(2)} Bio.";
    if (val > 1e9) return "${(val / 1e9).toStringAsFixed(2)} Mrd.";
    if (val > 1e6) return "${(val / 1e6).toStringAsFixed(2)} Mio.";
    return val.toStringAsFixed(0);
  }
}
