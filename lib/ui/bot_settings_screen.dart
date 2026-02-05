import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/portfolio_service.dart';

class BotSettingsScreen extends StatelessWidget {
  const BotSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bot = context.watch<PortfolioService>();

    return Scaffold(
      appBar: AppBar(title: const Text("Bot Konfiguration")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Start / Stop ---
          Card(
            color: bot.autoRun ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            child: SwitchListTile(
              title: const Text("Bot Aktiv (Auto-Run)"),
              subtitle: Text(bot.autoRun ? "Läuft im Hintergrund (1h Intervall)" : "Pausiert"),
              value: bot.autoRun,
              onChanged: (v) => bot.toggleAutoRun(v),
              secondary: Icon(bot.autoRun ? Icons.play_circle_fill : Icons.pause_circle_filled, color: bot.autoRun ? Colors.green : Colors.red),
            ),
          ),
          
          // Stop Button für laufende Routine (falls manuell gestartet)
          if (bot.isScanning)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () => bot.cancelRoutine(),
                icon: const Icon(Icons.stop),
                label: const Text("Laufenden Scan abbrechen"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              ),
            ),

          const SizedBox(height: 16),

          // --- Sektion: Routine Umfang (Performance) ---
          _buildSectionHeader(context, "Routine Umfang"),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Pending Orders prüfen"),
                  subtitle: const Text("Prüft ob Limit/Stop Orders ausgeführt wurden."),
                  value: bot.enableCheckPending,
                  onChanged: (v) => bot.updateRoutineFlags(pending: v),
                ),
                SwitchListTile(
                  title: const Text("Offene Positionen prüfen"),
                  subtitle: const Text("Prüft SL/TP und aktualisiert PnL."),
                  value: bot.enableCheckOpen,
                  onChanged: (v) => bot.updateRoutineFlags(open: v),
                ),
                SwitchListTile(
                  title: const Text("Nach neuen Trades suchen"),
                  subtitle: const Text("Scannt die Watchlist nach neuen Signalen."),
                  value: bot.enableScanNew,
                  onChanged: (v) => bot.updateRoutineFlags(scan: v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Sektion: Routine Umfang (Performance) ---
          _buildSectionHeader(context, "Routine Umfang"),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("Pending Orders prüfen"),
                  subtitle: const Text("Prüft ob Limit/Stop Orders ausgeführt wurden."),
                  value: bot.enableCheckPending,
                  onChanged: (v) => bot.updateRoutineFlags(pending: v),
                ),
                SwitchListTile(
                  title: const Text("Offene Positionen prüfen"),
                  subtitle: const Text("Prüft SL/TP und aktualisiert PnL."),
                  value: bot.enableCheckOpen,
                  onChanged: (v) => bot.updateRoutineFlags(open: v),
                ),
                SwitchListTile(
                  title: const Text("Nach neuen Trades suchen"),
                  subtitle: const Text("Scannt die Watchlist nach neuen Signalen."),
                  value: bot.enableScanNew,
                  onChanged: (v) => bot.updateRoutineFlags(scan: v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Sektion 1: Money Management ---
          _buildSectionHeader(context, "Money Management"),
          Card(
            child: Column(
              children: [
                _sliderTile(
                  "Invest pro Trade (€)", 
                  bot.botBaseInvest, 
                  10, 
                  2000, 
                  (v) => bot.updateBotSettings(v, bot.maxOpenPositions, bot.unlimitedPositions),
                  desc: "Wie viel Euro soll pro Trade investiert werden? Standard: 100€."
                ),
                SwitchListTile(
                  title: const Text("Unbegrenzte Positionen"),
                  subtitle: const Text("Ignoriert das Max-Limit"),
                  value: bot.unlimitedPositions,
                  onChanged: (v) => bot.updateBotSettings(bot.botBaseInvest, bot.maxOpenPositions, v),
                ),
                if (!bot.unlimitedPositions)
                  _sliderTile(
                    "Max. offene Positionen", 
                    bot.maxOpenPositions.toDouble(), 
                    1, 
                    50, 
                    (v) => bot.updateBotSettings(bot.botBaseInvest, v.toInt(), false),
                    desc: "Wie viele Trades darf der Bot gleichzeitig halten? Standard: 5."
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // --- Sektion 2: Strategie & Risiko (Bot) ---
          _buildSectionHeader(context, "Strategie & Risiko (Bot)"),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text("Diese Einstellungen steuern, wie der Bot SL und TP setzt.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          Card(
            child: Column(
              children: [
                _dropdownTile<int>(
                  "Entry Strategie",
                  bot.entryStrategy,
                  const {0: "Market (Sofort)", 1: "Pullback (Limit)", 2: "Breakout (Stop)"},
                  (v) => bot.updateStrategySettings(
                    entryStrategy: v!,
                    entryPadding: bot.entryPadding,
                    entryPaddingType: bot.entryPaddingType,
                    stopMethod: bot.stopMethod,
                    stopPercent: bot.stopPercent,
                    atrMult: bot.atrMult,
                    tpMethod: bot.tpMethod,
                    rrTp1: bot.rrTp1,
                    rrTp2: bot.rrTp2,
                    tpPercent1: bot.tpPercent1,
                    tpPercent2: bot.tpPercent2,
                    tp1SellFraction: bot.tp1SellFraction,
                  ),
                  subtitle: "Wann einsteigen? 'Market' kauft sofort. 'Pullback' wartet auf Rücksetzer (Limit). 'Breakout' kauft bei Ausbruch (Stop). Standard: Market.",
                ),
                if (bot.entryStrategy != 0) ...[
                  _dropdownTile<int>(
                    "Entry Padding Typ",
                    bot.entryPaddingType,
                    const {0: "Prozentual (%)", 1: "ATR Faktor (Volatilität)"},
                    (v) => bot.updateStrategySettings(
                      entryStrategy: bot.entryStrategy,
                      entryPadding: bot.entryPadding,
                      entryPaddingType: v!,
                      stopMethod: bot.stopMethod,
                      stopPercent: bot.stopPercent,
                      atrMult: bot.atrMult,
                      tpMethod: bot.tpMethod,
                      rrTp1: bot.rrTp1,
                      rrTp2: bot.rrTp2,
                      tpPercent1: bot.tpPercent1,
                      tpPercent2: bot.tpPercent2,
                      tp1SellFraction: bot.tp1SellFraction,
                    ),
                  ),
                  _sliderTile(
                    bot.entryPaddingType == 0 ? "Entry Padding %" : "Entry Padding (x ATR)", 
                    bot.entryPadding, 
                    0.1, 
                    bot.entryPaddingType == 0 ? 2.0 : 5.0, 
                    (v) => bot.updateStrategySettings(
                        entryPadding: v,
                        entryStrategy: bot.entryStrategy,
                        entryPaddingType: bot.entryPaddingType,
                        stopMethod: bot.stopMethod,
                        stopPercent: bot.stopPercent,
                        atrMult: bot.atrMult,
                        tpMethod: bot.tpMethod,
                        rrTp1: bot.rrTp1,
                        rrTp2: bot.rrTp2,
                        tpPercent1: bot.tpPercent1,
                        tp1SellFraction: bot.tp1SellFraction,
                        tpPercent2: bot.tpPercent2,
                      ),
                      desc: "Abstand zum aktuellen Kurs. Standard: 0.2% oder 0.5x ATR.",
                  ),
                ],
                const Divider(),
                _dropdownTile<int>(
                  "Stop Loss Methode",
                  bot.stopMethod,
                  const {0: "Donchian Low", 1: "Prozentual", 2: "ATR (Volatilität)"},
                  (v) => bot.updateStrategySettings(
                      stopMethod: v!,
                      stopPercent: bot.stopPercent,
                      atrMult: bot.atrMult,
                      tpMethod: bot.tpMethod,
                      rrTp1: bot.rrTp1,
                      rrTp2: bot.rrTp2,
                      tpPercent1: bot.tpPercent1,
                      tpPercent2: bot.tpPercent2,
                      entryStrategy: bot.entryStrategy,
                      entryPadding: bot.entryPadding,
                      entryPaddingType: bot.entryPaddingType,
                      tp1SellFraction: bot.tp1SellFraction),
                  subtitle: "Stop Loss Berechnung. ATR (Volatilität) ist empfohlen für Bots. Standard: ATR.",
                ),
                if (bot.stopMethod == 1)
                   _sliderTile("Stop Loss %", bot.stopPercent, 1, 20, (v) => bot.updateStrategySettings(
                        stopMethod: bot.stopMethod,
                        stopPercent: v,
                        atrMult: bot.atrMult,
                        tpMethod: bot.tpMethod,
                        rrTp1: bot.rrTp1,
                        rrTp2: bot.rrTp2,
                        tpPercent1: bot.tpPercent1,
                        tpPercent2: bot.tpPercent2,
                        entryStrategy: bot.entryStrategy,
                        entryPadding: bot.entryPadding,
                        entryPaddingType: bot.entryPaddingType,
                        tp1SellFraction: bot.tp1SellFraction),
                        desc: "Fester Abstand in %. Standard: 5%."
                    ),
                if (bot.stopMethod == 2 || bot.tpMethod == 2)
                   _sliderTile("ATR Multiplikator", bot.atrMult, 1, 5, (v) => bot.updateStrategySettings(
                        stopMethod: bot.stopMethod,
                        stopPercent: bot.stopPercent,
                        atrMult: v,
                        tpMethod: bot.tpMethod,
                        rrTp1: bot.rrTp1,
                        rrTp2: bot.rrTp2,
                        tpPercent1: bot.tpPercent1,
                        tpPercent2: bot.tpPercent2,
                        entryStrategy: bot.entryStrategy,
                        entryPadding: bot.entryPadding,
                        entryPaddingType: bot.entryPaddingType,
                        tp1SellFraction: bot.tp1SellFraction),
                        desc: "Faktor für Volatilität. 2.0x ist Standard für Swing-Trading. Kleiner = Enger."
                    ),
                
                const Divider(),
                
                _dropdownTile<int>(
                  "Take Profit Methode",
                  bot.tpMethod,
                  const {0: "Risk/Reward (CRV)", 1: "Prozentual", 2: "ATR-Ziel"},
                  (v) => bot.updateStrategySettings(
                      stopMethod: bot.stopMethod,
                      stopPercent: bot.stopPercent,
                      atrMult: bot.atrMult,
                      tpMethod: v!,
                      rrTp1: bot.rrTp1,
                      rrTp2: bot.rrTp2,
                      tpPercent1: bot.tpPercent1,
                      tpPercent2: bot.tpPercent2,
                      entryStrategy: bot.entryStrategy,
                      entryPadding: bot.entryPadding,
                      entryPaddingType: bot.entryPaddingType,
                      tp1SellFraction: bot.tp1SellFraction),
                  subtitle: "Gewinnmitnahme. CRV (Risk/Reward) basiert auf dem Risiko. Standard: CRV.",
                ),
                _sliderTile(
                  "TP1 Verkauf %",
                  bot.tp1SellFraction * 100,
                  10,
                  100,
                  (v) => bot.updateStrategySettings(
                    tp1SellFraction: v / 100.0,
                    stopMethod: bot.stopMethod, stopPercent: bot.stopPercent, atrMult: bot.atrMult,
                    tpMethod: bot.tpMethod, rrTp1: bot.rrTp1, rrTp2: bot.rrTp2,
                    tpPercent1: bot.tpPercent1, tpPercent2: bot.tpPercent2,
                    entryStrategy: bot.entryStrategy, entryPadding: bot.entryPadding, entryPaddingType: bot.entryPaddingType,
                  ),
                  desc: "Wie viel % der Position bei TP1 verkaufen? Standard: 50%.",
                ),
                if (bot.tpMethod == 0 || bot.tpMethod == 2) ...[
                   _sliderTile("TP1 Faktor", bot.rrTp1, 1, 5, (v) => bot.updateStrategySettings(
                        stopMethod: bot.stopMethod,
                        stopPercent: bot.stopPercent,
                        atrMult: bot.atrMult,
                        tpMethod: bot.tpMethod,
                        rrTp1: v,
                        rrTp2: bot.rrTp2,
                        tpPercent1: bot.tpPercent1,
                        tpPercent2: bot.tpPercent2,
                        entryStrategy: bot.entryStrategy,
                        entryPadding: bot.entryPadding,
                        entryPaddingType: bot.entryPaddingType,
                        tp1SellFraction: bot.tp1SellFraction),
                        desc: "Ziel 1: Vielfaches des Risikos. Standard: 1.5x."
                    ),
                   _sliderTile("TP2 Faktor", bot.rrTp2, 2, 10, (v) => bot.updateStrategySettings(
                        stopMethod: bot.stopMethod,
                        stopPercent: bot.stopPercent,
                        atrMult: bot.atrMult,
                        tpMethod: bot.tpMethod,
                        rrTp1: bot.rrTp1,
                        rrTp2: v,
                        tpPercent1: bot.tpPercent1,
                        tpPercent2: bot.tpPercent2,
                        entryStrategy: bot.entryStrategy,
                        entryPadding: bot.entryPadding,
                        entryPaddingType: bot.entryPaddingType,
                        tp1SellFraction: bot.tp1SellFraction),
                        desc: "Ziel 2: Vielfaches des Risikos. Standard: 3.0x."
                    ),
                ],
                if (bot.tpMethod == 1) ...[
                  _sliderTile("TP1 %", bot.tpPercent1, 1, 20, (v) => bot.updateStrategySettings(
                        stopMethod: bot.stopMethod,
                        stopPercent: bot.stopPercent,
                        atrMult: bot.atrMult,
                        tpMethod: bot.tpMethod,
                        rrTp1: bot.rrTp1,
                        rrTp2: bot.rrTp2,
                        tpPercent1: v,
                        tpPercent2: bot.tpPercent2,
                        entryStrategy: bot.entryStrategy,
                        entryPadding: bot.entryPadding,
                        tp1SellFraction: bot.tp1SellFraction,
                        entryPaddingType: bot.entryPaddingType,
                      ),
                      desc: "Ziel 1 in %. Standard: 5%."
                  ),
                  _sliderTile("TP2 %", bot.tpPercent2, 2, 50, (v) => bot.updateStrategySettings(
                        stopMethod: bot.stopMethod,
                        stopPercent: bot.stopPercent,
                        atrMult: bot.atrMult,
                        tpMethod: bot.tpMethod,
                        rrTp1: bot.rrTp1,
                        rrTp2: bot.rrTp2,
                        tpPercent1: bot.tpPercent1,
                        tpPercent2: v,
                        entryStrategy: bot.entryStrategy,
                        entryPadding: bot.entryPadding,
                        tp1SellFraction: bot.tp1SellFraction,
                        entryPaddingType: bot.entryPaddingType,
                      ),
                      desc: "Ziel 2 in %. Standard: 10%."
                  ),
                ],
                const SizedBox(height: 12),
                Center(child: TextButton.icon(
                  icon: const Icon(Icons.restore),
                  label: const Text("Auf Standardwerte zurücksetzen"),
                  onPressed: () => bot.resetBotSettings(),
                )),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // --- Sektion 3: Automatisierung & Trailing ---
          _buildSectionHeader(context, "Erweitert / Automatisierung"),
          Card(
            child: Column(
              children: [
                _sliderTile("Scan Intervall (Minuten)", bot.autoIntervalMinutes.toDouble(), 15, 240, 
                  (v) => bot.updateAdvancedSettings(v.toInt(), bot.trailingMult, bot.dynamicSizing),
                  desc: "Wie oft soll der Bot scannen? Standard: 60 Min."),
                
                _sliderTile("Trailing Stop (ATR Faktor)", bot.trailingMult, 0.5, 4.0, 
                  (v) => bot.updateAdvancedSettings(bot.autoIntervalMinutes, v, bot.dynamicSizing),
                  desc: "Abstand beim Nachziehen des Stops. Standard: 1.5x ATR."),
                
                SwitchListTile(
                  title: const Text("Dynamische Positionsgröße"),
                  subtitle: const Text("Einsatz verdoppeln bei Score > 80. Standard: An."),
                  value: bot.dynamicSizing,
                  onChanged: (v) => bot.updateAdvancedSettings(bot.autoIntervalMinutes, bot.trailingMult, v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }

  Widget _sliderTile(String label, double value, double min, double max, Function(double) onChanged, {String? desc}) {
    // Dynamische Steps:
    // Bei kleinen Ranges (z.B. 0.1 - 5.0) wollen wir 0.1 Schritte -> (max-min)*10 Divisions
    // Bei großen Ranges (z.B. 10 - 2000) reichen grobe Schritte.
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
            children: [Text(label), Text(value.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold))],
          ),
        ),
        Slider(value: value, min: min, max: max, divisions: divisions > 0 ? divisions : 1, onChanged: onChanged),
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
        underline: Container(), // Entfernt den Strich
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      ),
    );
  }
}