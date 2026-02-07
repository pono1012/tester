import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/app_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final s = provider.settings;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Einstellungen"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Ansicht", icon: Icon(Icons.visibility)),
              Tab(text: "Chart", icon: Icon(Icons.show_chart)),
              Tab(text: "Strategie", icon: Icon(Icons.settings_applications)),
              Tab(text: "Daten", icon: Icon(Icons.data_usage)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Ansicht & Allgemein
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGroupCard(context, "Ansicht & Allgemein", [
                  SwitchListTile(
                    title: const Text("Dunkles Design"),
                    value: provider.themeMode == ThemeMode.dark,
                    onChanged: (_) => provider.toggleTheme(),
                  ),
                  SwitchListTile(
                    title: const Text("Candlesticks anzeigen"),
                    subtitle: const Text("Zeigt Kerzen statt Linie"),
                    value: s.showCandles,
                    onChanged: (v) =>
                        provider.updateSettings(s.copyWith(showCandles: v)),
                  ),
                  SwitchListTile(
                    title: const Text("Muster-Marker"),
                    value: s.showPatternMarkers,
                    onChanged: (v) =>
                        provider.updateSettings(s.copyWith(showPatternMarkers: v)),
                  ),
                  SwitchListTile(
                    title: const Text("Trading-Linien (TP/SL)"),
                    value: s.showTradeLines,
                    onChanged: (v) =>
                        provider.updateSettings(s.copyWith(showTradeLines: v)),
                  ),
                ]),
              ],
            ),

            // Tab 2: Chart (Indikatoren und Zusatz-Graphen)
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGroupCard(context, "Indikatoren im Chart", [
                  SwitchListTile(
                    title: const Text("EMA 20 Linie"),
                    value: s.showEMA,
                    onChanged: (v) => provider.updateSettings(s.copyWith(showEMA: v)),
                  ),
                  SwitchListTile(
                    title: const Text("Bollinger Bands"),
                    value: s.showBB,
                    onChanged: (v) => provider.updateSettings(s.copyWith(showBB: v)),
                  ),
                  _sliderTile(
                      "Projektion (Tage)",
                      s.projectionDays.toDouble(),
                      5,
                      90,
                      (v) => provider
                          .updateSettings(s.copyWith(projectionDays: v.toInt()))),
                ]),
                const SizedBox(height: 16),
                _buildGroupCard(context, "Zusatz-Graphen (unten)", [
                  SwitchListTile(
                    title: const Text("Volumen Chart"),
                    value: s.showVolume,
                    onChanged: (v) =>
                        provider.updateSettings(s.copyWith(showVolume: v)),
                  ),
                  SwitchListTile(
                    title: const Text("RSI Indikator"),
                    value: s.showRSI,
                    onChanged: (v) => provider.updateSettings(s.copyWith(showRSI: v)),
                  ),
                  SwitchListTile(
                    title: const Text("MACD Indikator"),
                    value: s.showMACD,
                    onChanged: (v) =>
                        provider.updateSettings(s.copyWith(showMACD: v)),
                  ),
                  SwitchListTile(
                    title: const Text("Stochastic Oszillator"),
                    value: s.showStochastic,
                    onChanged: (v) =>
                        provider.updateSettings(s.copyWith(showStochastic: v)),
                  ),
                  SwitchListTile(
                    title: const Text("On-Balance Volume (OBV)"),
                    value: s.showOBV,
                    onChanged: (v) => provider.updateSettings(s.copyWith(showOBV: v)),
                  ),
                  SwitchListTile(
                    title: const Text("ADX (Trendstärke)"),
                    value: s.showAdx,
                    onChanged: (v) => provider.updateSettings(s.copyWith(showAdx: v)),
                  ),
                ]),
              ],
            ),

            // Tab 3: Strategie
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGroupCard(context, "Manuelle Analyse Strategie", [
                  _dropdownTile<int>(
                    "Entry Strategie",
                    s.entryStrategy,
                    const {0: "Market (Sofort)", 1: "Pullback (Limit)", 2: "Breakout (Stop)"},
                    (v) => provider.updateSettings(s.copyWith(entryStrategy: v)),
                    subtitle: "Wann einsteigen? 'Market' kauft sofort. 'Pullback' wartet auf günstigeren Preis. 'Breakout' kauft bei Ausbruch nach oben (teurer). Empfohlen: Market oder Pullback.",
                  ),
                  if (s.entryStrategy != 0) ...[
                    _dropdownTile<int>(
                      "Entry Padding Typ",
                      s.entryPaddingType,
                      const {0: "Prozentual (%)", 1: "ATR Faktor"},
                      (v) => provider.updateSettings(s.copyWith(entryPaddingType: v)),
                    ),
                    _sliderTile(
                      s.entryPaddingType == 0 ? "Entry Padding %" : "Entry Padding (x ATR)",
                      s.entryPadding,
                      0.1,
                      s.entryPaddingType == 0 ? 2.0 : 5.0,
                      (v) => provider.updateSettings(s.copyWith(entryPadding: v)),
                      desc: "Abstand zum aktuellen Kurs für die Order. Standard: 0.2% oder 0.5x ATR.",
                    ),
                  ],
                  const Divider(),
                  _dropdownTile<int>(
                    "Stop Loss Methode",
                    s.stopMethod,
                    const {0: "Donchian Low", 1: "Prozentual", 2: "ATR (Volatilität)"},
                    (v) => provider.updateSettings(s.copyWith(stopMethod: v)),
                    subtitle: "Wie wird der Stop Loss gesetzt? ATR passt sich der Marktschwankung an (Profi-Standard). Donchian nutzt das letzte Tief.",
                  ),
                  if (s.stopMethod == 1)
                    _sliderTile("Stop Loss %", s.stopPercent, 1, 20,
                        (v) => provider.updateSettings(s.copyWith(stopPercent: v)),
                        desc: "Fester prozentualer Abstand. Standard: 5-8%."),
                  if (s.stopMethod == 2 || s.tpMethod == 2)
                    _sliderTile("ATR Multiplikator", s.atrMult, 1, 5,
                        (v) => provider.updateSettings(s.copyWith(atrMult: v)),
                        desc: "Wie viel 'Luft' hat der Trade? 2.0x ATR ist Standard für Swing-Trading. Kleiner = engerer Stop."),
                  
                  const Divider(),
                  _dropdownTile<int>(
                    "Take Profit Methode",
                    s.tpMethod,
                    const {0: "Risk/Reward (CRV)", 1: "Prozentual", 2: "ATR-Ziel"},
                    (v) => provider.updateSettings(s.copyWith(tpMethod: v)),
                    subtitle: "Wann Gewinne mitnehmen? CRV (Risk/Reward) basiert auf dem Risiko (Stop Loss Abstand). Empfohlen: CRV.",
                  ),
                  if (s.tpMethod == 0 || s.tpMethod == 2) ...[
                    _sliderTile("TP1 Faktor", s.rrTp1, 1, 5,
                        (v) => provider.updateSettings(s.copyWith(rrTp1: v)),
                        desc: "Erstes Ziel: Vielfaches des Risikos. Standard: 1.5x (bei 100€ Risiko -> 150€ Gewinn)."),
                    _sliderTile("TP2 Faktor", s.rrTp2, 2, 10,
                        (v) => provider.updateSettings(s.copyWith(rrTp2: v)),
                        desc: "Zweites Ziel (Moonbag). Standard: 3.0x."),
                  ],
                  if (s.tpMethod == 1) ...[
                    _sliderTile("TP1 %", s.tpPercent1, 1, 20,
                        (v) => provider.updateSettings(s.copyWith(tpPercent1: v)),
                        desc: "Fester Gewinn in %. Standard: 5-10%."),
                    _sliderTile("TP2 %", s.tpPercent2, 2, 50,
                        (v) => provider.updateSettings(s.copyWith(tpPercent2: v)),
                        desc: "Fernes Ziel in %. Standard: 10-20%."),
                  ],
                  const SizedBox(height: 12),
                  Center(child: TextButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text("Auf Standardwerte zurücksetzen"),
                    onPressed: () => provider.resetStrategySettings(),
                  )),
                ]),
              ],
            ),

            // Tab 4: Daten & Info
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGroupCard(context, "Datenquellen", [
                  const Text("Chart: Stooq.com (Frei)"),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Alpha Vantage API Key (für Fundamentals)",
                      hintText: "Hier Key eingeben (optional)",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        provider.updateSettings(s.copyWith(alphaVantageKey: v)),
                    controller: TextEditingController(text: s.alphaVantageKey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "FMP API Key (Financial Modeling Prep)",
                      hintText: "Key eingeben",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        provider.updateSettings(s.copyWith(fmpKey: v)),
                    controller: TextEditingController(text: s.fmpKey),
                  ),
                ]),
                const SizedBox(height: 20),
                Center(
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final ver = snapshot.data?.version ?? "1.0.0";
                      final build = snapshot.data?.buildNumber ?? "0";
                      return Text("Version $ver+$build",
                          style: const TextStyle(color: Colors.grey));
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(
      BuildContext context, String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text(title,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
            ...children
          ],
        ),
      ),
    );
  }

  Widget _sliderTile(String label, double value, double min, double max,
      Function(double) onChanged, {String? desc}) {
    int divisions = 100;
    if (max - min <= 10) {
      divisions = ((max - min) * 10).toInt(); // 0.1 Schritte
    } else if (max - min <= 100) {
      divisions = (max - min).toInt(); // 1.0 Schritte
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(label), Text(value.toStringAsFixed(1))],
          ),
        ),
        Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions > 0 ? divisions : 1,
            onChanged: onChanged),
        if (desc != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
      ],
    );
  }

  Widget _dropdownTile<T>(String title, T value, Map<T, String> items, Function(T?) onChanged, {String? subtitle}) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: DropdownButton<T>(
        value: value,
        onChanged: onChanged,
        underline: Container(),
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      ),
    );
  }
}
