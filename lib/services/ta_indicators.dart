import 'dart:math' as math;
import '../models/models.dart';

// Hilfsklassen für Rückgabewerte
class MACDOut {
  final List<double?> macd, signal, hist;
  MACDOut(this.macd, this.signal, this.hist);
}

class BollingerOut {
  final List<double?> up, mid, lo;
  BollingerOut(this.up, this.mid, this.lo);
}

class SupertrendOut {
  final List<double?> line;
  final List<bool> bull;
  SupertrendOut(this.line, this.bull);
}

class DonchianOut {
  final List<double?> up, mid, lo;
  DonchianOut(this.up, this.mid, this.lo);
}

class StochasticOut {
  final List<double?> k, d;
  StochasticOut(this.k, this.d);
}

class AdxOut {
  final List<double?> adx, diPlus, diMinus;
  AdxOut(this.adx, this.diPlus, this.diMinus);
}

class FibonacciOut {
  final double maxLevel; // 100% (Top)
  final double minLevel; // 0% (Bottom)
  final double level236;
  final double level382;
  final double level500;
  final double level618;

  FibonacciOut({
    required this.maxLevel,
    required this.minLevel,
    required this.level236,
    required this.level382,
    required this.level500,
    required this.level618,
  });
}

class PivotPointsOut {
  final List<double?> pp, r1, r2, s1, s2;
  PivotPointsOut(this.pp, this.r1, this.r2, this.s1, this.s2);
}

class IchimokuOut {
  final List<double?> tenkan, kijun, spanA, spanB, chikou;
  IchimokuOut(this.tenkan, this.kijun, this.spanA, this.spanB, this.chikou);
}

class DivergenceResult {
  final List<int> bullishIndices;
  final List<int> bearishIndices;
  DivergenceResult(this.bullishIndices, this.bearishIndices);
}

class TA {
  // --- Hilfsfunktionen ---
  static double? _safeDiv(num a, num b) {
    if (b == 0) return null;
    return a / b;
  }

  static List<double?> sma(List<double> x, int n) {
    final out = List<double?>.filled(x.length, null);
    if (x.length < n) return out;
    double s = 0;
    for (int i = 0; i < x.length; i++) {
      s += x[i];
      if (i >= n) s -= x[i - n];
      if (i >= n - 1) out[i] = s / n;
    }
    return out;
  }

  static List<double?> ema(List<double> x, int n) {
    final out = List<double?>.filled(x.length, null);
    if (x.isEmpty) return out;
    final k = 2 / (n + 1);
    double? prev;
    for (int i = 0; i < x.length; i++) {
      final v = x[i];
      if (prev == null) {
        prev = v;
        out[i] = v;
      } else {
        prev = v * k + prev * (1 - k);
        out[i] = prev;
      }
    }
    return out;
  }

  static List<double> rma(List<double> x, int n) {
    final out = List<double>.filled(x.length, 0);
    if (x.isEmpty) return out;
    double prev = x[0];
    out[0] = prev;
    for (int i = 1; i < x.length; i++) {
      prev = (prev * (n - 1) + x[i]) / n;
      out[i] = prev;
    }
    return out;
  }

  static List<double?> rsi(List<double> x, {int n = 14}) {
    final out = List<double?>.filled(x.length, null);
    if (x.length < n + 1) return out;

    double avgGain = 0;
    double avgLoss = 0;

    // 1. Initialen Durchschnitt berechnen (Simple Average)
    for (int i = 1; i <= n; i++) {
      final ch = x[i] - x[i - 1];
      if (ch > 0) {
        avgGain += ch;
      } else {
        avgLoss += -ch;
      }
    }
    avgGain /= n;
    avgLoss /= n;

    // Erster RSI Wert
    double rs = avgLoss == 0 ? 100.0 : avgGain / avgLoss;
    out[n] = 100 - 100 / (1 + rs);

    // 2. Wilder's Smoothing für den Rest
    for (int i = n + 1; i < x.length; i++) {
      final ch = x[i] - x[i - 1];
      final double currentGain = ch > 0 ? ch : 0.0;
      final double currentLoss = ch < 0 ? -ch : 0.0;

      avgGain = (avgGain * (n - 1) + currentGain) / n;
      avgLoss = (avgLoss * (n - 1) + currentLoss) / n;

      rs = avgLoss == 0 ? 100.0 : avgGain / avgLoss;
      out[i] = 100 - 100 / (1 + rs);
    }
    return out;
  }

  static MACDOut macd(List<double> x,
      {int fast = 12, int slow = 26, int signal = 9}) {
    final eFast = ema(x, fast);
    final eSlow = ema(x, slow);
    final macdLine = List<double?>.generate(x.length, (i) {
      final a = eFast[i], b = eSlow[i];
      if (a == null || b == null) return null;
      return a - b;
    });

    final validMacd = <double>[];
    final indices = <int>[];
    for (int i = 0; i < macdLine.length; i++) {
      if (macdLine[i] != null) {
        validMacd.add(macdLine[i]!);
        indices.add(i);
      }
    }

    final sigRaw = ema(validMacd, signal);
    final sigOut = List<double?>.filled(x.length, null);
    final histOut = List<double?>.filled(x.length, null);

    for (int k = 0; k < validMacd.length; k++) {
      final idx = indices[k];
      sigOut[idx] = sigRaw[k];
      if (macdLine[idx] != null && sigOut[idx] != null) {
        histOut[idx] = macdLine[idx]! - sigOut[idx]!;
      }
    }
    return MACDOut(macdLine, sigOut, histOut);
  }

  static BollingerOut bollinger(List<double> x, {int n = 20, double k = 2}) {
    final m = sma(x, n);
    final outU = List<double?>.filled(x.length, null);
    final outL = List<double?>.filled(x.length, null);
    for (int i = 0; i < x.length; i++) {
      if (m[i] != null) {
        double s = 0;
        int count = 0;
        for (int j = math.max(0, i - n + 1); j <= i; j++) {
          final d = x[j] - m[i]!;
          s += d * d;
          count++;
        }
        if (count > 1) {
          final std = math.sqrt(s / count);
          outU[i] = m[i]! + k * std;
          outL[i] = m[i]! - k * std;
        }
      }
    }
    return BollingerOut(outU, m, outL);
  }

  static SupertrendOut supertrend(List<PriceBar> bars,
      {int atrLen = 10, double mult = 3}) {
    if (bars.isEmpty) return SupertrendOut([], []);
    final h = bars.map((b) => b.high).toList();
    final l = bars.map((b) => b.low).toList();
    final c = bars.map((b) => b.close).toList();

    final tr = <double>[];
    for (int i = 0; i < bars.length; i++) {
      final cur = h[i] - l[i];
      if (i == 0)
        tr.add(cur);
      else {
        final p = c[i - 1];
        tr.add(math.max(cur, math.max((h[i] - p).abs(), (l[i] - p).abs())));
      }
    }
    final atr = rma(tr, atrLen);

    final finalU = List<double>.filled(bars.length, 0);
    final finalL = List<double>.filled(bars.length, 0);
    final basicU = List<double>.filled(bars.length, 0);
    final basicL = List<double>.filled(bars.length, 0);

    final line = List<double?>.filled(bars.length, null);
    final bull = List<bool>.filled(bars.length, true);

    for (int i = 0; i < bars.length; i++) {
      if (i < atrLen) continue;

      basicU[i] = (h[i] + l[i]) / 2 + mult * atr[i];
      basicL[i] = (h[i] + l[i]) / 2 - mult * atr[i];

      if (i == atrLen) {
        finalU[i] = basicU[i];
        finalL[i] = basicL[i];
      } else {
        finalU[i] = (basicU[i] < finalU[i - 1] || c[i - 1] > finalU[i - 1])
            ? basicU[i]
            : finalU[i - 1];
        finalL[i] = (basicL[i] > finalL[i - 1] || c[i - 1] < finalL[i - 1])
            ? basicL[i]
            : finalL[i - 1];
      }

      if (i == atrLen) {
        bull[i] = true;
        line[i] = finalL[i];
      } else {
        if (bull[i - 1]) {
          if (c[i] > finalL[i]) {
            bull[i] = true;
            line[i] = finalL[i];
          } else {
            bull[i] = false;
            line[i] = finalU[i];
          }
        } else {
          if (c[i] < finalU[i]) {
            bull[i] = false;
            line[i] = finalU[i];
          } else {
            bull[i] = true;
            line[i] = finalL[i];
          }
        }
      }
    }
    return SupertrendOut(line, bull);
  }

  static DonchianOut donchian(List<PriceBar> bars, {int n = 20}) {
    final up = List<double?>.filled(bars.length, null);
    final lo = List<double?>.filled(bars.length, null);
    final mid = List<double?>.filled(bars.length, null);
    for (int i = 0; i < bars.length; i++) {
      if (i >= n - 1) {
        double hi = -double.infinity, loW = double.infinity;
        for (int j = i - n + 1; j <= i; j++) {
          hi = math.max(hi, bars[j].high);
          loW = math.min(loW, bars[j].low);
        }
        up[i] = hi;
        lo[i] = loW;
        mid[i] = (hi + loW) / 2;
      }
    }
    return DonchianOut(up, mid, lo);
  }

  static AdxOut calcAdx(List<PriceBar> bars, {int len = 14}) {
    if (bars.length < len * 2) return AdxOut([], [], []);

    final tr = <double>[];
    final dmP = <double>[];
    final dmM = <double>[];

    for (int i = 0; i < bars.length; i++) {
      if (i == 0) {
        tr.add(bars[i].high - bars[i].low);
        dmP.add(0);
        dmM.add(0);
      } else {
        final h = bars[i].high, l = bars[i].low;
        final pH = bars[i - 1].high, pL = bars[i - 1].low;
        final pC = bars[i - 1].close;

        tr.add(math.max(h - l, math.max((h - pC).abs(), (l - pC).abs())));

        final up = h - pH;
        final down = pL - l;

        if (up > down && up > 0)
          dmP.add(up);
        else
          dmP.add(0);
        if (down > up && down > 0)
          dmM.add(down);
        else
          dmM.add(0);
      }
    }

    final trS = rma(tr, len);
    final dmPS = rma(dmP, len);
    final dmMS = rma(dmM, len);

    final dx = <double>[];

    for (int i = 0; i < bars.length; i++) {
      if (trS[i] == 0) {
        dx.add(0);
        continue;
      }
      final dp = 100 * dmPS[i] / trS[i];
      final dm = 100 * dmMS[i] / trS[i];

      final sum = dp + dm;
      if (sum == 0)
        dx.add(0);
      else
        dx.add(100 * (dp - dm).abs() / sum);
    }

    final adx = rma(dx, len);
    final adxOut = List<double?>.filled(bars.length, null);
    for (int i = len; i < bars.length; i++) {
      adxOut[i] = adx[i];
    }

    return AdxOut(
        adxOut, [], []); // diPlus/Minus hier weggelassen wenn nicht benötigt
  }

  static List<bool> squeezeFlags(List<PriceBar> bars,
      {int bbLen = 20,
      double bbMult = 2,
      int atrLen = 20,
      double atrMult = 1.5}) {
    final closes = bars.map((b) => b.close).toList();
    final bb = bollinger(closes, n: bbLen, k: bbMult);
    final ema20 = ema(closes, atrLen).map((e) => e ?? 0).toList();
    final tr = <double>[];
    for (int i = 0; i < bars.length; i++) {
      final cur = bars[i].high - bars[i].low;
      if (i == 0)
        tr.add(cur);
      else {
        final p = bars[i - 1].close;
        tr.add(math.max(
            cur, math.max((bars[i].high - p).abs(), (bars[i].low - p).abs())));
      }
    }
    final atr = rma(tr, atrLen);
    final kcU =
        List<double>.generate(bars.length, (i) => ema20[i] + atrMult * atr[i]);
    final kcL =
        List<double>.generate(bars.length, (i) => ema20[i] - atrMult * atr[i]);
    final flags = List<bool>.filled(bars.length, false);
    for (int i = 0; i < bars.length; i++) {
      final bu = bb.up[i], bl = bb.lo[i];
      if (bu != null && bl != null) {
        flags[i] = bu < kcU[i] && bl > kcL[i];
      }
    }
    return flags;
  }

  static String detectPattern(List<PriceBar> bars) {
    if (bars.length < 3) return "Keine Daten";
    final last = bars.last;
    final prev = bars[bars.length - 2];
    final prev2 = bars[bars.length - 3];

    double body = (last.close - last.open).abs();
    double range = (last.high - last.low).abs();
    if (range == 0) return "Flat";

    double upperWick = last.high - math.max(last.open, last.close);
    double lowerWick = math.min(last.open, last.close) - last.low;
    bool isBull = last.close > last.open;
    bool isBear = last.close < last.open;

    // --- Erweiterte Mustererkennung (Trendwende) ---

    // Double Top (M-Pattern) - Sehr vereinfacht: Suche nach zwei Hochs in den letzten 20 Bars
    if (bars.length > 20) {
      double maxH = -1.0;
      int maxIdx = -1;
      // Suche höchstes Hoch der letzten 20 Tage (ohne heute)
      for (int i = bars.length - 20; i < bars.length - 5; i++) {
        if (bars[i].high > maxH) {
          maxH = bars[i].high;
          maxIdx = i;
        }
      }
      // Wenn aktuelles Hoch nahe dem alten Hoch ist (+/- 1%) und dazwischen tiefer war
      if (maxIdx != -1 && (last.high - maxH).abs() / maxH < 0.01) {
        return "Double Top (Möglich)";
      }
    }

    // Three White Soldiers (Bullish)
    if (bars.length > 3) {
      if (last.close > last.open &&
          prev.close > prev.open &&
          prev2.close > prev2.open &&
          last.close > prev.close &&
          prev.close > prev2.close) return "3 White Soldiers";
    }

    // Engulfing
    if (isBull &&
        prev.close < prev.open &&
        last.close >= prev.open &&
        last.open <= prev.close &&
        body > (prev.close - prev.open).abs()) return "Bullish Engulfing";
    if (isBear &&
        prev.close > prev.open &&
        last.open >= prev.close &&
        last.close <= prev.open &&
        body > (prev.close - prev.open).abs()) return "Bearish Engulfing";

    // Hammer / Shooting Star
    if (lowerWick > 2 * body && upperWick < body) return "Hammer";
    if (upperWick > 2 * body && lowerWick < body) return "Shooting Star";

    if (body <= 0.1 * range) return "Doji";

    return "Kein Muster";
  }

  static ProjectionResult? projectCone(List<double> closes, int days) {
    if (closes.length < 10 || days <= 0) return null;

    // Helper für Lineare Regression
    List<double> calcLinReg(List<double> data) {
      int n = data.length;
      double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
      for (int i = 0; i < n; i++) {
        sumX += i;
        sumY += data[i];
        sumXY += i * data[i];
        sumXX += i * i;
      }
      final denom = n * sumXX - sumX * sumX;
      if (denom == 0) return [0, data.last];
      final slope = (n * sumXY - sumX * sumY) / denom;
      final intercept = (sumY - slope * sumX) / n;
      return [slope, intercept];
    }

    // 1. Langfristiger Trend (30 Tage)
    final nLong = 30;
    final startLong = math.max(0, closes.length - nLong);
    final dataLong = closes.sublist(startLong);
    final resLong = calcLinReg(dataLong);
    final slopeLong = resLong[0];

    // 2. Kurzfristiger Trend (10 Tage) - für bessere Reaktivität
    final nShort = 10;
    final startShort = math.max(0, closes.length - nShort);
    final dataShort = closes.sublist(startShort);
    final resShort = calcLinReg(dataShort);
    final slopeShort = resShort[0];

    // 3. Gewichteter Winkel: 60% Kurzfristig, 40% Langfristig
    // Das macht die Projektion "schneller" bei Trendwechseln
    final a = (slopeShort * 0.6) + (slopeLong * 0.4);

    // 4. Volatilität berechnen (Standardabweichung der letzten 14 Tage)
    // Statt Regression Error nehmen wir echte Vola für den Kegel
    final nVola = 14;
    final startVola = math.max(0, closes.length - nVola);
    final dataVola = closes.sublist(startVola);
    final mean = dataVola.reduce((a, b) => a + b) / dataVola.length;
    double sumSq = 0;
    for (var v in dataVola) sumSq += (v - mean) * (v - mean);
    final stdDev = math.sqrt(sumSq / dataVola.length);

    final mid = <double?>[];
    final upper = <double?>[];
    final lower = <double?>[];

    // Startpunkt der Projektion ist der letzte echte Wert
    final lastVal = closes.last;

    for (int i = 1; i <= days; i++) {
      // Projektion startet beim letzten echten Kurs
      final y = lastVal + (a * i);

      // Kegel weitet sich basierend auf Vola (Probability Cone)
      // Faktor 1.5 * StdDev * sqrt(Zeit) ist statistisch üblich für Preis-Diffusion
      final coneWidth = 1.5 * stdDev * math.sqrt(i);

      mid.add(y);
      upper.add(y + coneWidth);
      lower.add(y - coneWidth);
    }
    return ProjectionResult(mid, upper, lower);
  }

  // ATR Helper für Provider
  static List<double?> atr(List<PriceBar> bars, {int period = 14}) {
    final tr = <double>[];
    for (int i = 0; i < bars.length; i++) {
      final cur = bars[i].high - bars[i].low;
      if (i == 0)
        tr.add(cur);
      else {
        final p = bars[i - 1].close;
        tr.add(math.max(
            cur, math.max((bars[i].high - p).abs(), (bars[i].low - p).abs())));
      }
    }
    final atrRaw = rma(tr, period);
    final out = List<double?>.filled(bars.length, null);
    for (int i = period; i < bars.length; i++) out[i] = atrRaw[i];
    return out;
  }

  static StochasticOut stochastic(List<PriceBar> bars,
      {int n = 14, int dSmooth = 3}) {
    final kLine = List<double?>.filled(bars.length, null);
    if (bars.length < n)
      return StochasticOut(kLine, List<double?>.filled(bars.length, null));

    for (int i = n - 1; i < bars.length; i++) {
      double highestHigh = -double.infinity;
      double lowestLow = double.infinity;
      for (int j = i - n + 1; j <= i; j++) {
        highestHigh = math.max(highestHigh, bars[j].high);
        lowestLow = math.min(lowestLow, bars[j].low);
      }
      final range = highestHigh - lowestLow;
      kLine[i] = range > 0 ? (bars[i].close - lowestLow) / range * 100 : 50;
    }

    // Calculate %D line (SMA of %K) - Optimiert
    final validK = <double>[];
    final indices = <int>[];
    for (int i = 0; i < kLine.length; i++) {
      if (kLine[i] != null) {
        validK.add(kLine[i]!);
        indices.add(i);
      }
    }

    final dSma = sma(validK, dSmooth);
    final dLine = List<double?>.filled(bars.length, null);
    for (int i = 0; i < dSma.length; i++) {
      dLine[indices[i]] = dSma[i];
    }
    return StochasticOut(kLine, dLine);
  }

  static List<double?> obv(List<PriceBar> bars) {
    final out = List<double?>.filled(bars.length, null);
    if (bars.isEmpty) return out;

    double currentObv = 0;
    out[0] = 0;

    for (int i = 1; i < bars.length; i++) {
      if (bars[i].close > bars[i - 1].close) {
        currentObv += bars[i].volume;
      } else if (bars[i].close < bars[i - 1].close) {
        currentObv -= bars[i].volume;
      }
      out[i] = currentObv;
    }
    return out;
  }

  // --- Neue Features ---

  // 1. Fibonacci Retracements (High/Low der letzten N Perioden)
  static FibonacciOut? calcFibonacci(List<PriceBar> bars, {int periods = 200}) {
    if (bars.isEmpty) return null;
    final start = math.max(0, bars.length - periods);
    final subset = bars.sublist(start);

    double maxH = -double.infinity;
    double minL = double.infinity;

    for (var b in subset) {
      if (b.high > maxH) maxH = b.high;
      if (b.low < minL) minL = b.low;
    }

    if (maxH == -double.infinity || minL == double.infinity) return null;

    final diff = maxH - minL;
    return FibonacciOut(
      maxLevel: maxH,
      minLevel: minL,
      level236: maxH - (diff * 0.236),
      level382: maxH - (diff * 0.382),
      level500: maxH - (diff * 0.5),
      level618: maxH - (diff * 0.618),
    );
  }

  // 2. Pivot Points (Standard) - Basierend auf Vortag
  static PivotPointsOut pivotPoints(List<PriceBar> bars) {
    final pp = List<double?>.filled(bars.length, null);
    final r1 = List<double?>.filled(bars.length, null);
    final r2 = List<double?>.filled(bars.length, null);
    final s1 = List<double?>.filled(bars.length, null);
    final s2 = List<double?>.filled(bars.length, null);

    for (int i = 1; i < bars.length; i++) {
      final prev = bars[i - 1];
      final p = (prev.high + prev.low + prev.close) / 3;
      pp[i] = p;
      r1[i] = 2 * p - prev.low;
      s1[i] = 2 * p - prev.high;
      r2[i] = p + (prev.high - prev.low);
      s2[i] = p - (prev.high - prev.low);
    }
    return PivotPointsOut(pp, r1, r2, s1, s2);
  }

  // 3. Ichimoku Cloud
  static IchimokuOut ichimoku(List<PriceBar> bars,
      {int tenkanLen = 9, int kijunLen = 26, int senkouBLen = 52}) {
    // Helper für (Max + Min) / 2
    double? _mid(int idx, int len) {
      if (idx < len - 1) return null;
      double h = -double.infinity;
      double l = double.infinity;
      for (int i = idx - len + 1; i <= idx; i++) {
        h = math.max(h, bars[i].high);
        l = math.min(l, bars[i].low);
      }
      return (h + l) / 2;
    }

    final tenkan = List<double?>.filled(bars.length, null);
    final kijun = List<double?>.filled(bars.length, null);
    final spanA = List<double?>.filled(bars.length, null);
    final spanB = List<double?>.filled(bars.length, null);
    final chikou = List<double?>.filled(bars.length, null);

    for (int i = 0; i < bars.length; i++) {
      tenkan[i] = _mid(i, tenkanLen);
      kijun[i] = _mid(i, kijunLen);

      // Span A: (Tenkan + Kijun) / 2 -> Gehört eigentlich 26 Perioden in die Zukunft
      // Wir speichern es hier bei 'i', die UI muss es verschieben (oder wir shiften hier)
      // Standard: Berechnung heute, Plot in Zukunft.
      if (tenkan[i] != null && kijun[i] != null) {
        spanA[i] = (tenkan[i]! + kijun[i]!) / 2;
      }

      // Span B: (Max + Min) / 2 über 52 Perioden -> Gehört 26 Perioden in die Zukunft
      spanB[i] = _mid(i, senkouBLen);

      // Chikou: Close -> Gehört 26 Perioden in die Vergangenheit
      chikou[i] = bars[i].close;
    }

    return IchimokuOut(tenkan, kijun, spanA, spanB, chikou);
  }

  // 4. Divergenzen (Preis vs RSI)
  static DivergenceResult detectDivergences(
      List<double> prices, List<double?> rsiValues,
      {int lookback = 30}) {
    final bullish = <int>[];
    final bearish = <int>[];

    if (prices.length < 5 || rsiValues.length != prices.length)
      return DivergenceResult([], []);

    // 1 = Peak, -1 = Valley, 0 = None
    int isPivot(List<double?> data, int i) {
      if (i < 2 || i >= data.length - 2) return 0;
      final v = data[i];
      if (v == null || data[i - 1] == null || data[i + 1] == null) return 0;
      if (v > data[i - 1]! && v > data[i + 1]!) return 1; // High
      if (v < data[i - 1]! && v < data[i + 1]!) return -1; // Low
      return 0;
    }

    final recentHighs = <int>[];
    final recentLows = <int>[];

    for (int i = 2; i < prices.length - 2; i++) {
      if (rsiValues[i] == null) continue;

      // Bearish: Preis macht höheres Hoch, RSI macht tieferes Hoch
      if (isPivot(prices.cast<double?>(), i) == 1 && isPivot(rsiValues, i) == 1) {
        for (int k = recentHighs.length - 1; k >= 0; k--) {
          final prev = recentHighs[k];
          if (i - prev > lookback) break;
          if (prices[i] > prices[prev] && rsiValues[i]! < rsiValues[prev]!) {
            bearish.add(i);
            break;
          }
        }
        recentHighs.add(i);
      }

      // Bullish: Preis macht tieferes Tief, RSI macht höheres Tief
      if (isPivot(prices.cast<double?>(), i) == -1 && isPivot(rsiValues, i) == -1) {
        for (int k = recentLows.length - 1; k >= 0; k--) {
          final prev = recentLows[k];
          if (i - prev > lookback) break;
          if (prices[i] < prices[prev] && rsiValues[i]! > rsiValues[prev]!) {
            bullish.add(i);
            break;
          }
        }
        recentLows.add(i);
      }
    }
    return DivergenceResult(bullish, bearish);
  }
}
