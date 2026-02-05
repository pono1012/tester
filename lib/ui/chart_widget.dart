import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class ChartWidget extends StatelessWidget {
  const ChartWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final data = provider.computedData;

    if (provider.isLoading)
      return const Center(child: CircularProgressIndicator());
    if (provider.error != null)
      return Center(
          child:
              Text(provider.error!, style: const TextStyle(color: Colors.red)));
    if (data == null || data.bars.isEmpty)
      return const Center(child: Text("Keine Daten für Chart"));

    final bars = data.bars;
    // Min/Max Berechnung für Y-Achse
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var b in bars) {
      if (b.low < minY) minY = b.low;
      if (b.high > maxY) maxY = b.high;
    }
    final range = maxY - minY;

    // Check Projektion Bounds
    if (data.proj != null) {
      for (var v in data.proj!.upper) {
        if (v != null && v > maxY) maxY = v;
      }
      for (var v in data.proj!.lower) {
        if (v != null && v < minY) minY = v;
      }
    }

    minY -= range * 0.05;
    maxY += range * 0.05;

    final priceSpots =
        List.generate(bars.length, (i) => FlSpot(i.toDouble(), bars[i].close));

    // Trade Lines (TP/SL)
    final extraLines = <HorizontalLine>[];
    if (provider.settings.showTradeLines && data.latestSignal != null) {
      final sig = data.latestSignal!;
      // Entry
      if (sig.entryPrice.isFinite)
        extraLines.add(HorizontalLine(
            y: sig.entryPrice,
            color: Colors.blue,
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
                show: true, labelResolver: (l) => "Entry")));
      // SL
      if (sig.stopLoss.isFinite)
        extraLines.add(HorizontalLine(
            y: sig.stopLoss,
            color: Colors.red,
            strokeWidth: 2,
            label:
                HorizontalLineLabel(show: true, labelResolver: (l) => "SL")));
      // TP
      if (sig.takeProfit1.isFinite)
        extraLines.add(HorizontalLine(
            y: sig.takeProfit1,
            color: Colors.green,
            strokeWidth: 2,
            label:
                HorizontalLineLabel(show: true, labelResolver: (l) => "TP1")));
      if (sig.takeProfit2.isFinite)
        extraLines.add(HorizontalLine(
            y: sig.takeProfit2,
            color: Colors.green.withOpacity(0.5),
            strokeWidth: 1,
            label:
                HorizontalLineLabel(show: true, labelResolver: (l) => "TP2")));
    }

    // --- Candle Logic ---
    if (provider.settings.showCandles) {
      return Padding(
        padding: const EdgeInsets.only(right: 16, left: 0, top: 24, bottom: 12),
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData:
                const FlTitlesData(show: false), // Vereinfacht für Candles
            borderData: FlBorderData(
                show: true, border: Border.all(color: Colors.white12)),
            barGroups: List.generate(bars.length, (i) {
              final b = bars[i];
              final isUp = b.close >= b.open;
              return BarChartGroupData(
                x: i,
                barRods: [
                  // Wick (Docht)
                  BarChartRodData(
                    toY: b.high,
                    fromY: b.low,
                    color: isUp ? Colors.green : Colors.red,
                    width: 1,
                  ),
                  // Body (Körper)
                  BarChartRodData(
                    toY: b.close,
                    fromY: b.open,
                    color: isUp ? Colors.green : Colors.red,
                    width: 4,
                  ),
                ],
              );
            }),
          ),
        ),
      );
    }

    // --- Line Chart Logic (Standard) ---

    // Bollinger Bands Spots
    final bbUpSpots = <FlSpot>[];
    final bbLoSpots = <FlSpot>[];
    if (provider.settings.showBB && data.bbUp.isNotEmpty) {
      for (int i = 0; i < bars.length; i++) {
        if (data.bbUp[i] != null)
          bbUpSpots.add(FlSpot(i.toDouble(), data.bbUp[i]!));
        if (data.bbLo[i] != null)
          bbLoSpots.add(FlSpot(i.toDouble(), data.bbLo[i]!));
      }
    }

    // Projection Spots
    final projMid = <FlSpot>[];
    final projUp = <FlSpot>[];
    final projLo = <FlSpot>[];

    if (data.proj != null) {
      // Startpunkt ist der letzte Bar
      final startX = bars.length.toDouble() - 1;
      final lastClose = bars.last.close;

      // Farbe anpassen für Light/Dark Mode
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final projColor = isDark ? Colors.white.withOpacity(0.5) : Colors.black54;

      // Verbinde letzten echten Punkt mit Projektion
      projMid.add(FlSpot(startX, lastClose));
      projUp.add(FlSpot(startX, lastClose));
      projLo.add(FlSpot(startX, lastClose));

      for (int i = 0; i < data.proj!.mid.length; i++) {
        final x = startX + 1 + i;
        if (data.proj!.mid[i] != null)
          projMid.add(FlSpot(x, data.proj!.mid[i]!));
        if (data.proj!.upper[i] != null)
          projUp.add(FlSpot(x, data.proj!.upper[i]!));
        if (data.proj!.lower[i] != null)
          projLo.add(FlSpot(x, data.proj!.lower[i]!));
      }
    }

    // X-Achse erweitern für Projektion
    double maxX = bars.length.toDouble() - 1;
    if (data.proj != null) maxX += provider.settings.projectionDays;

    // Aufbau der Linien für den Chart
    final List<LineChartBarData> lineBars = [];

    // 1. Preis Linie (Index 0)
    lineBars.add(LineChartBarData(
      spots: priceSpots,
      isCurved: false,
      color: Colors.blueAccent,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData:
          BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)),
    ));

    // 2. EMA 20
    if (provider.settings.showEMA && data.ema20.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: data.ema20
            .asMap()
            .entries
            .where((e) => e.value != null)
            .map((e) => FlSpot(e.key.toDouble(), e.value!))
            .toList(),
        color: Colors.amber,
        barWidth: 1,
        dotData: const FlDotData(show: false),
      ));
    }

    // 3. SMA 50
    if (data.sma50.isNotEmpty) {
      lineBars.add(LineChartBarData(
        spots: data.sma50
            .asMap()
            .entries
            .where((e) => e.value != null)
            .map((e) => FlSpot(e.key.toDouble(), e.value!))
            .toList(),
        color: Colors.white70,
        barWidth: 1,
        dotData: const FlDotData(show: false),
      ));
    }

    // 4. Bollinger Bands
    if (provider.settings.showBB) {
      lineBars.add(LineChartBarData(
          spots: bbUpSpots,
          isCurved: true,
          color: Colors.blue.withOpacity(0.3),
          barWidth: 1,
          dotData: const FlDotData(show: false)));
      lineBars.add(LineChartBarData(
          spots: bbLoSpots,
          isCurved: true,
          color: Colors.blue.withOpacity(0.3),
          barWidth: 1,
          dotData: const FlDotData(show: false)));
    }

    // 5. Projektion (mit Füllung)
    List<BetweenBarsData> betweenBars = [];
    if (data.proj != null) {
      // Mittellinie
      lineBars.add(LineChartBarData(
        spots: projMid,
        isCurved: true,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.5)
            : Colors.black54,
        barWidth: 1,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        dashArray: [5, 5],
      ));

      // Obere Grenze (Index merken)
      final upIndex = lineBars.length;
      lineBars.add(LineChartBarData(
        spots: projUp,
        isCurved: true,
        color: Colors.greenAccent.withOpacity(0.3),
        barWidth: 1,
        dotData: const FlDotData(show: false),
        dashArray: [2, 4],
      ));

      // Untere Grenze (Index merken)
      final loIndex = lineBars.length;
      lineBars.add(LineChartBarData(
        spots: projLo,
        isCurved: true,
        color: Colors.redAccent.withOpacity(0.3),
        barWidth: 1,
        dotData: const FlDotData(show: false),
        dashArray: [2, 4],
      ));

      // Füllung dazwischen
      betweenBars.add(BetweenBarsData(
        fromIndex: upIndex,
        toIndex: loIndex,
        color: Colors.blueGrey.withOpacity(0.15), // Leichte Färbung des Kegels
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(right: 16, left: 0, top: 24, bottom: 12),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            bottomTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) {
                  if (value < minY || value > maxY) return const SizedBox();
                  return Text(value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 10));
                },
              ),
            ),
          ),
          borderData: FlBorderData(
              show: true, border: Border.all(color: Colors.white12)),
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          extraLinesData: ExtraLinesData(horizontalLines: extraLines),
          lineBarsData: lineBars,
          betweenBarsData: betweenBars,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(spot.y.toStringAsFixed(2),
                      const TextStyle(color: Colors.white));
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
