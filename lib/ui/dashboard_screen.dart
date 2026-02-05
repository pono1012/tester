import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import 'chart_widget.dart';
import 'score_details_screen.dart';
import 'settings_screen.dart';
import 'pattern_details_screen.dart';
import 'fundamental_analysis_screen.dart';
import 'news_screen.dart';
import 'bot_dashboard_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchCtrl = TextEditingController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _searchCtrl.text = p.symbol;

    Future.microtask(() => p.fetchData());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final data = provider.computedData;

    // Wir nutzen ein Scaffold für die Hauptnavigation.
    // Wenn wir im "Analyse" Tab sind (Index 0), zeigen wir die AppBar hier.
    // Bei Bot (1) und Settings (2) lassen wir die Child-Widgets ihre eigene AppBar/Scaffold haben.
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Text(""),
              elevation: 0,
              scrolledUnderElevation: 2,
            )
          : null, // Kein AppBar für Bot/Settings hier, die haben eigene
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Tab 0: Analyse Dashboard
          _buildAnalyseTab(context, provider, data),
          // Tab 1: AutoTrader Bot
          const BotDashboardScreen(),
          // Tab 2: Einstellungen
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics),
              label: "Analyse"),
          NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy),
              label: "AutoBot"),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: "Settings"),
        ],
      ),
    );
  }

  Widget _buildAnalyseTab(
      BuildContext context, AppProvider provider, ComputedData? data) {
    return SafeArea(
      child: Column(
        children: [
          // Suche & Zeitraum
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            decoration: BoxDecoration(
              color: Theme.of(context).appBarTheme.backgroundColor ??
                  Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                  bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                            hintText: "Symbol suchen (z.B. AAPL.US)",
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)))),
                        onSubmitted: (v) {
                          provider.setSymbol(v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // NEU: Intervall- und Range-Auswahl
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Intervall-Auswahl
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Wrap(
                        spacing: 6.0,
                        children: TimeFrame.values.map((interval) {
                          final isSelected = provider.selectedTimeFrame == interval;
                          return ChoiceChip(
                            label: Text(interval.label),
                            labelStyle: TextStyle(fontSize: 12, color: isSelected ? Theme.of(context).colorScheme.onPrimary : null),
                            selected: isSelected,
                            onSelected: (bool selected) {
                              if (selected) {
                                provider.setTimeFrame(interval);
                              }
                            },
                            selectedColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ),
                    // Chart-Range Dropdown
                    DropdownButton<ChartRange>(
                      underline: Container(),
                      icon: const Icon(Icons.date_range),
                      value: provider.selectedChartRange,
                      onChanged: (v) => provider.setChartRange(v!),
                      items: const [
                        DropdownMenuItem(value: ChartRange.week1, child: Text("1W")),
                        DropdownMenuItem(value: ChartRange.month1, child: Text("1M")),
                        DropdownMenuItem(value: ChartRange.quarter1, child: Text("3M")),
                        DropdownMenuItem(value: ChartRange.year1, child: Text("1Y")),
                        DropdownMenuItem(value: ChartRange.year2, child: Text("2Y")),
                        DropdownMenuItem(value: ChartRange.year3, child: Text("3Y")),
                        DropdownMenuItem(value: ChartRange.year5, child: Text("5Y")),
                      ],
                    )
                  ],
                ),
                // History Chips
                if (provider.searchHistory.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      height: 30,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: provider.searchHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final sym = provider.searchHistory[index];
                          return ActionChip(
                            label:
                                Text(sym, style: const TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              _searchCtrl.text = sym;
                              provider.setSymbol(sym);
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (provider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (provider.error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                          child: Text("Fehler: ${provider.error}",
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.fetchData(),
                      child: const Text("Erneut versuchen"),
                    )
                  ],
                ),
              ),
            )
          else ...[
            // --- Hauptchart ---
            const Expanded(flex: 5, child: ChartWidget()),

            // --- Fundamentalanalyse Button ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FundamentalAnalysisScreen(
                                    symbol: provider.yahooSymbol,
                                    apiKey: provider.settings.fmpKey ?? "")));
                      },
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text("Fundamentals"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    NewsScreen(symbol: provider.yahooSymbol)));
                      },
                      icon: const Icon(Icons.newspaper, size: 18),
                      label: const Text("News (Yahoo)"),
                    ),
                  ),
                ],
              ),
            ),

            // --- Scoreboard (Feste Höhe statt Expanded, damit es nicht gequetscht wird) ---
            SizedBox(
              height: 100,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                  border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1)),
                ),
                child: data?.latestSignal == null
                    ? const Center(child: Text("Keine Analyse"))
                    : Row(
                        children: [
                          // Linke Seite: Score & Typ (Klickbar für Details)
                          Expanded(
                            flex: 4,
                            child: InkWell(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ScoreDetailsScreen())),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Trading Score",
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                  // Fix für RenderFlex Overflow: FittedBox skaliert den Inhalt herunter, wenn er zu breit ist
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        Text("${data!.latestSignal!.score}",
                                            style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold)),
                                        const Text("/100",
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                                height: 2)),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: (data.latestSignal!.type
                                                          .contains("Buy")
                                                      ? Colors.green
                                                      : (data.latestSignal!.type
                                                              .contains("Sell")
                                                          ? Colors.red
                                                          : Colors.grey))
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4)),
                                          child: Text(
                                              data.latestSignal!.type
                                                  .replaceAll(" ", "\n"),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  height: 1.1,
                                                  color: data.latestSignal!.type
                                                          .contains("Buy")
                                                      ? Colors.green
                                                      : (data.latestSignal!.type
                                                              .contains("Sell")
                                                          ? Colors.red
                                                          : Colors.grey))),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Mitte: Trade Levels (Entry, SL, TP)
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildCompactRow(
                                      "Entry",
                                      data.latestSignal!.entryPrice,
                                      Colors.blue),
                                  _buildCompactRow("SL",
                                      data.latestSignal!.stopLoss, Colors.red),
                                  _buildCompactRow(
                                      "TP1",
                                      data.latestSignal!.takeProfit1,
                                      Colors.green),
                                  _buildCompactRow(
                                      "TP2",
                                      data.latestSignal!.takeProfit2,
                                      Colors.green.withOpacity(0.7)),
                                ],
                              ),
                            ),
                          ),
                          // Rechte Seite: Muster (Klickbar für Erklärung)
                          InkWell(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => PatternDetailsScreen(
                                        patternName:
                                            data.latestSignal!.chartPattern))),
                            child: Container(
                              width: 100,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.candlestick_chart,
                                        size: 24, color: Colors.blueAccent),
                                    const SizedBox(height: 4),
                                    Text(data.latestSignal!.chartPattern,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // --- Indikator Charts ---
            if (data != null) ...[
              // Volumen
              if (provider.settings.showVolume)
                Expanded(
                    flex: 2,
                    child: _buildIndicatorWrapper(
                        context,
                        "Volumen",
                        _formatVolume(data.bars.last.volume),
                        _buildVolumeChart(data))),

              // RSI
              if (provider.settings.showRSI)
                Expanded(
                    flex: 2,
                    child: _buildIndicatorWrapper(context, "RSI (14)",
                        _formatRsi(data.rsi.last), _buildRSIChart(data))),

              // MACD
              if (provider.settings.showMACD)
                Expanded(
                    flex: 2,
                    child: _buildIndicatorWrapper(
                        context,
                        "MACD",
                        _formatMacd(data.macdHist.last),
                        _buildMACDChart(data))),

              // Stochastic
              if (provider.settings.showStochastic)
                Expanded(
                    flex: 2,
                    child: _buildIndicatorWrapper(
                        context,
                        "Stochastic",
                        _formatStochastic(data.stochK.last),
                        _buildStochasticChart(data))),

              // OBV
              if (provider.settings.showOBV)
                Expanded(
                    flex: 2,
                    child: _buildIndicatorWrapper(context, "On-Balance Volume",
                        _formatObv(data.obv.last), _buildOBVChart(data))),

              // ADX (Neu)
              if (provider.settings.showAdx)
                Expanded(
                    flex: 2,
                    child: _buildIndicatorWrapper(
                        context,
                        "ADX (Trendstärke)",
                        "${data.adx.last?.toStringAsFixed(1)}",
                        _buildADXChart(data))),
            ],
          ],
        ],
      ),
    );
  }

  String _formatVolume(int v) {
    if (v > 1000000) return "${(v / 1000000).toStringAsFixed(2)}M";
    if (v > 1000) return "${(v / 1000).toStringAsFixed(1)}k";
    return "$v";
  }

  String _formatRsi(double? rsi) {
    if (rsi == null) return "-";
    String status = "Neutral";
    if (rsi > 70) status = "Überkauft";
    if (rsi < 30) status = "Überverkauft";
    return "${rsi.toStringAsFixed(1)} ($status)";
  }

  String _formatMacd(double? hist) {
    if (hist == null) return "-";
    String status = hist > 0 ? "Positiv" : "Negativ";
    return "${hist.toStringAsFixed(4)} ($status)";
  }

  String _formatStochastic(double? k) {
    if (k == null) return "-";
    String status = "Neutral";
    if (k > 80) status = "Überkauft";
    if (k < 20) status = "Überverkauft";
    return "${k.toStringAsFixed(1)} ($status)";
  }

  String _formatObv(double? v) {
    if (v == null) return "-";
    if (v.abs() > 1000000) return "${(v / 1000000).toStringAsFixed(2)}M";
    if (v.abs() > 1000) return "${(v / 1000).toStringAsFixed(1)}k";
    return v.toStringAsFixed(0);
  }

  Widget _buildCompactRow(String label, double val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(val.toStringAsFixed(2),
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildIndicatorWrapper(
      BuildContext context, String title, String value, Widget chart) {
    return GestureDetector(
      onTap: () {
        // Fullscreen Chart Dialog
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              height: 400,
              child: Column(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Aktueller Wert: $value",
                      style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Expanded(child: chart), // Wiederverwendung des Chart Widgets
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Schließen"))
                ],
              ),
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Row(children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
              const SizedBox(width: 8),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontFamily: "monospace",
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              const Icon(Icons.fullscreen, size: 14, color: Colors.grey),
            ]),
          ),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildVolumeChart(ComputedData data) {
    final bars = data.bars;
    // Wir nehmen nicht das absolute Max, um Ausreißer abzufedern, oder wir cappen es.
    double maxV = 0;
    for (var b in bars) if (b.volume > maxV) maxV = b.volume.toDouble();
    if (maxV == 0) maxV = 100;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.black12,
      child: BarChart(
        BarChartData(
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(bars.length, (i) {
            final isUp = bars[i].close >= bars[i].open;
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: bars[i].volume.toDouble(),
                color: isUp
                    ? Colors.green.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
                width: 2,
              )
            ]);
          }),
          maxY: maxV,
        ),
      ),
    );
  }

  Widget _buildRSIChart(ComputedData data) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.black12,
      child: LineChart(
        LineChartData(
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(
                show: true, drawVerticalLine: false, horizontalInterval: 30),
            borderData: FlBorderData(
                show: true, border: Border.all(color: Colors.white10)),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              LineChartBarData(
                  spots: List.generate(data.rsi.length,
                      (i) => FlSpot(i.toDouble(), data.rsi[i] ?? 50)),
                  color: Colors.purpleAccent,
                  dotData: const FlDotData(show: false),
                  barWidth: 1)
            ],
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(
                  y: 70,
                  color: Colors.red.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [5, 5]),
              HorizontalLine(
                  y: 30,
                  color: Colors.green.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [5, 5]),
            ])),
      ),
    );
  }

  Widget _buildMACDChart(ComputedData data) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.black12,
      child: LineChart(
        LineChartData(
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(
              show: true, border: Border.all(color: Colors.white10)),
          lineBarsData: [
            LineChartBarData(
                spots: List.generate(data.macd.length,
                    (i) => FlSpot(i.toDouble(), data.macd[i] ?? 0)),
                color: Colors.blue,
                dotData: const FlDotData(show: false),
                barWidth: 1),
            LineChartBarData(
                spots: List.generate(data.macdSignal.length,
                    (i) => FlSpot(i.toDouble(), data.macdSignal[i] ?? 0)),
                color: Colors.orange,
                dotData: const FlDotData(show: false),
                barWidth: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildStochasticChart(ComputedData data) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.black12,
      child: LineChart(
        LineChartData(
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(
                show: true, drawVerticalLine: false, horizontalInterval: 40),
            borderData: FlBorderData(
                show: true, border: Border.all(color: Colors.white10)),
            minY: 0,
            maxY: 100,
            lineBarsData: [
              // %K line
              LineChartBarData(
                  spots: List.generate(data.stochK.length,
                      (i) => FlSpot(i.toDouble(), data.stochK[i] ?? 50)),
                  color: Colors.cyan,
                  dotData: const FlDotData(show: false),
                  barWidth: 1),
              // %D line
              LineChartBarData(
                  spots: List.generate(data.stochD.length,
                      (i) => FlSpot(i.toDouble(), data.stochD[i] ?? 50)),
                  color: Colors.amber,
                  dotData: const FlDotData(show: false),
                  barWidth: 1),
            ],
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(
                  y: 80,
                  color: Colors.red.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [5, 5]),
              HorizontalLine(
                  y: 20,
                  color: Colors.green.withOpacity(0.5),
                  strokeWidth: 1,
                  dashArray: [5, 5]),
            ])),
      ),
    );
  }

  Widget _buildOBVChart(ComputedData data) {
    // OBV can have large values, so we don't set min/max Y
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.black12,
      child: LineChart(
        LineChartData(
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(
              show: true, border: Border.all(color: Colors.white10)),
          lineBarsData: [
            LineChartBarData(
                spots: List.generate(data.obv.length,
                    (i) => FlSpot(i.toDouble(), data.obv[i] ?? 0)),
                color: Colors.lightGreenAccent,
                dotData: const FlDotData(show: false),
                barWidth: 1)
          ],
        ),
      ),
    );
  }

  Widget _buildADXChart(ComputedData data) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Colors.black12,
      child: LineChart(
        LineChartData(
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(
                show: true, drawVerticalLine: false, horizontalInterval: 25),
            borderData: FlBorderData(
                show: true, border: Border.all(color: Colors.white10)),
            minY: 0,
            maxY: 60, // ADX geht selten über 60
            lineBarsData: [
              LineChartBarData(
                  spots: List.generate(data.adx.length,
                      (i) => FlSpot(i.toDouble(), data.adx[i] ?? 0)),
                  color: Colors.blueAccent,
                  dotData: const FlDotData(show: false),
                  barWidth: 2)
            ],
            extraLinesData: ExtraLinesData(horizontalLines: [
              HorizontalLine(
                  y: 25,
                  color: Colors.white54,
                  strokeWidth: 1,
                  dashArray: [5, 5]), // Trend-Schwelle
            ])),
      ),
    );
  }
}
