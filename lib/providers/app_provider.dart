import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/data_service.dart';
import '../services/ta_indicators.dart';

class AppProvider extends ChangeNotifier {
  final DataService _ds = DataService();
  ThemeMode _themeMode = ThemeMode.dark;
  String _symbol = 'DAX';
  String _yahooSymbol = '^GDAXI'; // Separater Ticker für Yahoo
  TimeFrame _selectedTimeFrame = TimeFrame.d1; // NEU: Kerzen-Intervall
  ChartRange _selectedChartRange = ChartRange.year1; // ALT: Anzeige-Zeitraum
  AppSettings _settings = AppSettings(); // Default Settings
  List<String> _searchHistory = [];

  List<PriceBar> _fullBars = [];
  FundamentalData? _fundamentalData;
  ComputedData? _computedData;
  bool _isLoading = false;
  String? _error;

  // Einzel-Aktien Strategie Einstellungen entfernt (nur noch im Bot)

  ThemeMode get themeMode => _themeMode;
  String get symbol => _symbol;
  String get yahooSymbol => _yahooSymbol;
  TimeFrame get selectedTimeFrame => _selectedTimeFrame; // NEU
  ChartRange get selectedChartRange => _selectedChartRange; // ALT
  ComputedData? get computedData => _computedData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  AppSettings get settings => _settings;
  List<String> get searchHistory => _searchHistory;

  AppProvider() {
    _loadSettings();
  }

  void setSymbol(String s) {
    _symbol = s.toUpperCase();

    // Auto-Konvertierung: .US und .DEF entfernen für Yahoo/FMP
    String ySym = _symbol;
    if (ySym.endsWith(".US")) ySym = ySym.replaceAll(".US", "");
    if (ySym.endsWith(".DEF")) ySym = ySym.replaceAll(".DEF", ".DE");
    // if (ySym == '^DAX') ySym = '^GDAXI'; // DAX Mapping Stooq -> Yahoo

    _yahooSymbol = ySym;
    fetchData();
    _addToHistory(_symbol);
    _saveState();
  }

  void setYahooSymbol(String s) {
    _yahooSymbol = s.toUpperCase();
    fetchData(); // Lädt Daten neu (inkl. Fundamentals mit neuem Ticker)
  }

  // NEU: Setzt das Kerzen-Intervall und lädt die Daten neu
  void setTimeFrame(TimeFrame tf) {
    if (_selectedTimeFrame == tf) return;
    _selectedTimeFrame = tf;
    fetchData(); // Daten müssen mit neuem Intervall von der API geholt werden
    _saveState();
  }

  void setChartRange(ChartRange range) {
    _selectedChartRange = range;
    _recalculate();
    _saveState();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    _saveSettings();
  }

  void updateSettings(AppSettings newSettings) {
    _settings = newSettings;
    _recalculate(); // Neuberechnung triggern (für Strategie/Charts)
  }

  Future<void> fetchData() async {
    _isLoading = true;
    _error = null;
    _fundamentalData = null; // Reset alter Daten
    notifyListeners();

    try {
      // 1. Chart-Daten laden (Priorität) - mit dem ausgewählten Intervall
      _fullBars = await _ds.fetchBars(_symbol, interval: _selectedTimeFrame);
      if (_fullBars.isEmpty) throw Exception("Keine Daten");

      // Chart sofort anzeigen
      _recalculate();
      _isLoading = false;
      notifyListeners();

      // 2. Fundamentals im Hintergrund laden
      // Hier nutzen wir jetzt das separate Yahoo Symbol
      // UPDATE: User möchte KEIN ständiges Laden im Hintergrund für FMP.
      // Wir deaktivieren das automatische Laden hier komplett, um API Calls zu sparen.
      // Die Daten werden erst geladen, wenn der User auf das "Info"-Icon klickt.
      _fundamentalData = null;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    } finally {
      // finally Block entfernt, da wir oben granular steuern
    }
  }

  void _recalculate() {
    if (_fullBars.isEmpty) return;

    try {
      final closes = _fullBars.map((b) => b.close).toList();
      final int len = _fullBars.length;

      // Helper für sichere Berechnung (Smart Catching)
      // Wenn ein Indikator fehlschlägt, wird eine leere Liste zurückgegeben,
      // damit der Rest der App weiterläuft.
      List<T> safeCalc<T>(List<T> Function() func, T fallback) {
        try {
          final res = func();
          if (res.length != len) {
            return List.filled(len, fallback);
          }
          return res;
        } catch (e) {
          debugPrint("Indikator Fehler (ignoriert): $e");
          return List.filled(len, fallback);
        }
      }

      // 1. Indikatoren berechnen (Robust)
      final sma50 = safeCalc(() => TA.sma(closes, 50), null);
      final ema20 = safeCalc(() => TA.ema(closes, 20), null);
      final rsi = safeCalc(() => TA.rsi(closes), null);
      final atr = safeCalc(() => TA.atr(_fullBars), null);
      final bb = TA.bollinger(closes); // Returns object, safe inside?
      // Wir wrappen die komplexen Objekte manuell
      
      // MACD
      List<double?> macd, macdSignal, macdHist;
      try {
        final m = TA.macd(closes);
        macd = m.macd; macdSignal = m.signal; macdHist = m.hist;
      } catch (e) {
        macd = List.filled(len, null); macdSignal = List.filled(len, null); macdHist = List.filled(len, null);
      }

      // Bollinger
      List<double?> bbUp, bbMid, bbLo;
      try {
        final b = TA.bollinger(closes);
        bbUp = b.up; bbMid = b.mid; bbLo = b.lo;
      } catch (e) {
        bbUp = List.filled(len, null); bbMid = List.filled(len, null); bbLo = List.filled(len, null);
      }

      // Donchian
      List<double?> donUp, donMid, donLo;
      try {
        final d = TA.donchian(_fullBars);
        donUp = d.up; donMid = d.mid; donLo = d.lo;
      } catch (e) {
        donUp = List.filled(len, null); donMid = List.filled(len, null); donLo = List.filled(len, null);
      }

      // Supertrend
      List<double?> stLine; List<bool> stBull;
      try {
        final s = TA.supertrend(_fullBars);
        stLine = s.line; stBull = s.bull;
      } catch (e) {
        stLine = List.filled(len, null); stBull = List.filled(len, false);
      }

      // ADX
      List<double?> adx;
      try {
        adx = TA.calcAdx(_fullBars).adx;
      } catch (e) {
        adx = List.filled(len, null);
      }

      // Squeeze
      List<bool> squeeze;
      try {
        squeeze = TA.squeezeFlags(_fullBars);
      } catch (e) {
        squeeze = List.filled(len, false);
      }

      // Stochastic
      List<double?> stochK, stochD;
      try {
        final s = TA.stochastic(_fullBars);
        stochK = s.k; stochD = s.d;
      } catch (e) {
        stochK = List.filled(len, null); stochD = List.filled(len, null);
      }

      // OBV
      final obv = safeCalc(() => TA.obv(_fullBars), null);

      // Projection
      ProjectionResult? proj;
      try {
        proj = TA.projectCone(closes, _settings.projectionDays);
      } catch (e) {
        proj = null;
      }

      // 2. Score & Strategie Logik (Safe)
      final lastPrice = closes.last;
      final lastRsi = rsi.last ?? 50;
      final lastMacdHist = macdHist.last ?? 0;
      final lastEma20 = ema20.last ?? lastPrice;
      final lastAtr = atr.last ?? (lastPrice * 0.02);
      final lastStBull = stBull.isNotEmpty ? stBull.last : false;
      final lastStochK = stochK.last ?? 50;
      final lastObv = obv.last ?? 0;
      final lastAdx = adx.last ?? 0;

      // Sichere Extraktion Donchian
      double lastDonchianLo = lastPrice * 0.95;
      if (donLo.isNotEmpty) {
        for (final v in donLo.reversed) {
          if (v != null) { lastDonchianLo = v; break; }
        }
      }
      double lastDonchianUp = lastPrice * 1.05;
      if (donUp.isNotEmpty) {
        for (final v in donUp.reversed) {
          if (v != null) { lastDonchianUp = v; break; }
        }
      }

      String pattern = "Kein Muster";
      try {
        pattern = TA.detectPattern(_fullBars);
      } catch (_) {}

      // Scoring System (0 bis 100)
      int score = 50;
      List<String> reasons = [];

      // --- 1. Trend & Struktur (Basis) ---
      if (lastPrice > lastEma20) {
        score += 10;
        reasons.add("Kurs > EMA20 (Kurzfristig Bullish)");
      } else {
        score -= 10;
        reasons.add("Kurs < EMA20 (Kurzfristig Bearish)");
      }

      if (lastStBull) {
        score += 10;
        reasons.add("Supertrend ist Grün (Bullish)");
      } else {
        score -= 10;
        reasons.add("Supertrend ist Rot (Bearish)");
      }

      // --- 2. Momentum & ADX Filter ---
      bool strongTrend = lastAdx > 25;
      if (strongTrend) {
        if (lastRsi > 50 && lastRsi < 80) {
          score += 5; reasons.add("RSI bestätigt Trend (Momentum)");
        } else if (lastRsi >= 80) {
          score -= 10; reasons.add("RSI extrem überhitzt (>80)");
        } else if (lastRsi < 40) {
          score -= 5; reasons.add("RSI schwächelt im Trend");
        }
      } else {
        if (lastRsi > 70) {
          score -= 15; reasons.add("RSI überkauft in Range (Reversal)");
        } else if (lastRsi < 30) {
          score += 15; reasons.add("RSI überverkauft in Range (Bounce)");
        }
      }

      if (lastStochK < 20) {
        score += 10; reasons.add("Stochastic überverkauft");
      } else if (lastStochK > 80) {
        score -= (strongTrend ? 5 : 10); reasons.add("Stochastic überkauft");
      }

      // --- 3. Volumen & Squeeze ---
      if (obv.length > 5 && (lastObv > (obv[obv.length - 5] ?? 0))) {
        score += 5; reasons.add("OBV steigend (Kaufdruck)");
      } else {
        score -= 5;
      }

      if (squeeze.isNotEmpty && squeeze.last) {
        score += 10; reasons.add("TTM Squeeze aktiv (Ausbruch steht bevor)");
      }

      if (lastMacdHist > 0) {
        score += 5; reasons.add("MACD Momentum positiv");
      } else {
        score -= 5;
      }

      // --- 4. Pattern ---
      if (pattern.contains("Bullish") || pattern.contains("Hammer")) {
        score += 15; reasons.add("Muster: $pattern");
      }
      if (pattern.contains("Bearish") || pattern.contains("Shooting")) {
        score -= 15; reasons.add("Muster: $pattern");
      }

      score = score.clamp(0, 100);

      String type = "Neutral";
      if (score >= 80) type = "Strong Buy";
      else if (score >= 60) type = "Buy";
      else if (score <= 20) type = "Strong Sell";
      else if (score <= 40) type = "Sell";

      // 3. Entry / SL / TP
      bool isLong = score >= 50;
      double entry = lastPrice;
      
      double paddingVal = 0.0;
      if (_settings.entryPaddingType == 0) {
        paddingVal = lastPrice * (_settings.entryPadding / 100);
      } else {
        paddingVal = lastAtr * _settings.entryPadding;
      }

      if (_settings.entryStrategy == 1) {
        if (isLong) entry = lastPrice - paddingVal;
        else entry = lastPrice + paddingVal;
      } else if (_settings.entryStrategy == 2) {
        if (isLong) entry = _fullBars.last.high + paddingVal;
        else entry = _fullBars.last.low - paddingVal;
      }

      double sl, tp1, tp2;
      if (isLong) {
        if (_settings.stopMethod == 0) sl = lastDonchianLo;
        else if (_settings.stopMethod == 1) sl = lastPrice * (1 - _settings.stopPercent / 100);
        else sl = lastPrice - (_settings.atrMult * lastAtr);
        if (sl >= entry) sl = entry * 0.99;
      } else {
        if (_settings.stopMethod == 0) sl = lastDonchianUp;
        else if (_settings.stopMethod == 1) sl = lastPrice * (1 + _settings.stopPercent / 100);
        else sl = lastPrice + (_settings.atrMult * lastAtr);
        if (sl <= entry) sl = entry * 1.01;
      }

      final risk = (entry - sl).abs();
      if (isLong) {
        if (_settings.tpMethod == 1) {
          tp1 = entry * (1 + _settings.tpPercent1 / 100);
          tp2 = entry * (1 + _settings.tpPercent2 / 100);
        } else if (_settings.tpMethod == 2) {
          final atrRisk = lastAtr * _settings.atrMult;
          tp1 = entry + (atrRisk * _settings.rrTp1);
          tp2 = entry + (atrRisk * _settings.rrTp2);
        } else {
          tp1 = entry + (risk * _settings.rrTp1);
          tp2 = entry + (risk * _settings.rrTp2);
        }
      } else {
        tp1 = entry - (risk * _settings.rrTp1);
        tp2 = entry - (risk * _settings.rrTp2);
      }

      double crvRisk = (entry - sl).abs();
      double reward = (tp2 - entry).abs();
      double crv = crvRisk == 0 ? 0 : reward / crvRisk;

      final signal = TradeSignal(
        type: type,
        entryPrice: entry,
        stopLoss: sl,
        takeProfit1: tp1,
        takeProfit2: tp2,
        riskRewardRatio: crv,
        score: score,
        reasons: reasons,
        chartPattern: pattern,
        tp1Percent: ((tp1 - entry) / entry * 100).abs(),
        tp2Percent: ((tp2 - entry) / entry * 100).abs(),
      );

      // 4. Slicing für Chart
      int days = _settings.chartRangeDays;
      if (_selectedChartRange == ChartRange.week1) days = 14;
      if (_selectedChartRange == ChartRange.month1) days = 30;
      if (_selectedChartRange == ChartRange.quarter1) days = 90;
      if (_selectedChartRange == ChartRange.year1) days = 365;
      if (_selectedChartRange == ChartRange.year2) days = 365 * 2;
      if (_selectedChartRange == ChartRange.year3) days = 365 * 3;
      if (_selectedChartRange == ChartRange.year5) days = 365 * 5;

      int start = (_fullBars.length - days).clamp(0, _fullBars.length);
      List<T> slice<T>(List<T> l) => l.sublist(start);

      _computedData = ComputedData(
        bars: slice(_fullBars),
        sma50: slice(sma50),
        ema20: slice(ema20),
        rsi: slice(rsi),
        macd: slice(macd),
        macdSignal: slice(macdSignal),
        macdHist: slice(macdHist),
        atr: slice(atr),
        bbUp: slice(bbUp), bbMid: slice(bbMid), bbLo: slice(bbLo),
        donchianUp: slice(donUp), donchianMid: slice(donMid), donchianLo: slice(donLo),
        stLine: slice(stLine), stBull: slice(stBull),
        squeezeFlags: slice(squeeze),
        adx: slice(adx),
        stochK: slice(stochK), stochD: slice(stochD),
        obv: slice(obv),
        proj: proj,
        fundamentals: _fundamentalData,
        latestSignal: signal,
      );
      notifyListeners();

    } catch (e, stack) {
      debugPrint("Kritischer Fehler in _recalculate: $e\n$stack");
      // Fallback: Zeige zumindest den Chart ohne Indikatoren
      // Damit der User nicht vor einem leeren Screen sitzt.
      try {
        int days = _settings.chartRangeDays;
        int start = (_fullBars.length - days).clamp(0, _fullBars.length);
        final slicedBars = _fullBars.sublist(start);
        final len = slicedBars.length;

        _computedData = ComputedData(
          bars: slicedBars,
          sma50: List.filled(len, null),
          ema20: List.filled(len, null),
          rsi: List.filled(len, null),
          macd: List.filled(len, null),
          macdSignal: List.filled(len, null),
          macdHist: List.filled(len, null),
          atr: List.filled(len, null),
          bbUp: List.filled(len, null), bbMid: List.filled(len, null), bbLo: List.filled(len, null),
          donchianUp: List.filled(len, null), donchianMid: List.filled(len, null), donchianLo: List.filled(len, null),
          stLine: List.filled(len, null), stBull: List.filled(len, false),
          squeezeFlags: List.filled(len, false),
          adx: List.filled(len, null),
          stochK: List.filled(len, null), stochD: List.filled(len, null),
          obv: List.filled(len, null),
          proj: null,
          fundamentals: _fundamentalData,
          latestSignal: null,
        );
        notifyListeners();
      } catch (e2) {
        debugPrint("Selbst Fallback fehlgeschlagen: $e2");
        _error = "Datenfehler: $e";
        notifyListeners();
      }
    }
  }

  void _addToHistory(String sym) {
    if (_searchHistory.contains(sym)) {
      _searchHistory.remove(sym);
    }
    _searchHistory.insert(0, sym);
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    _saveState();
  }

  void clearHistory() {
    _searchHistory.clear();
    _saveState();
    notifyListeners();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_symbol', _symbol);
    await prefs.setInt('last_timeframe', _selectedTimeFrame.index); // NEU
    await prefs.setInt('last_chart_range', _selectedChartRange.index); // ALT
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    int idx = prefs.getInt('theme') ?? 1;
    String? avKey = prefs.getString('av_key');
    String? fmpKey = prefs.getString('fmp_key');

    // Load State
    String? lastSym = prefs.getString('last_symbol');
    if (lastSym != null && lastSym.isNotEmpty) {
      _symbol = lastSym;
      // Yahoo Symbol sync
      String ySym = _symbol;
      if (ySym.endsWith(".US")) ySym = ySym.replaceAll(".US", "");
      if (ySym.endsWith(".DEF")) ySym = ySym.replaceAll(".DEF", ".DE");
      if (ySym == '^DAX') ySym = '^GDAXI';
      _yahooSymbol = ySym;
    }
    // NEU: Lade das letzte Intervall
    int? tfIdx = prefs.getInt('last_timeframe'); // 'last_timeframe' wird jetzt für das Intervall verwendet
    if (tfIdx != null && tfIdx >= 0 && tfIdx < TimeFrame.values.length) {
      _selectedTimeFrame = TimeFrame.values[tfIdx];
    }
    // ALT: Lade den letzten Chart-Range
    int? rangeIdx = prefs.getInt('last_chart_range');
    if (rangeIdx != null && rangeIdx >= 0 && rangeIdx < ChartRange.values.length) {
      _selectedChartRange = ChartRange.values[rangeIdx];
    }
    _searchHistory = prefs.getStringList('search_history') ?? [];

    _themeMode = idx == 0 ? ThemeMode.light : ThemeMode.dark;
    if (avKey != null) _settings = _settings.copyWith(alphaVantageKey: avKey);
    if (fmpKey != null) _settings = _settings.copyWith(fmpKey: fmpKey);

    // Load Strategy Settings
    _settings = _settings.copyWith(
      entryStrategy: prefs.getInt('man_entry_strat') ?? 0,
      entryPadding: prefs.getDouble('man_entry_pad') ?? 0.2,
      entryPaddingType: prefs.getInt('man_entry_pad_type') ?? 0,
      stopMethod: prefs.getInt('man_stop_method') ?? 2,
      stopPercent: prefs.getDouble('man_stop_pct') ?? 5.0,
      atrMult: prefs.getDouble('man_atr_mult') ?? 2.0,
      tpMethod: prefs.getInt('man_tp_method') ?? 0,
      rrTp1: prefs.getDouble('man_rr_tp1') ?? 1.5,
      rrTp2: prefs.getDouble('man_rr_tp2') ?? 3.0,
      tpPercent1: prefs.getDouble('man_tp_pct1') ?? 5.0,
      tpPercent2: prefs.getDouble('man_tp_pct2') ?? 10.0,
    );
    notifyListeners();
  }

  // Setzt die Strategie-Parameter auf empfohlene Standardwerte zurück
  void resetStrategySettings() {
    _settings = _settings.copyWith(
      entryStrategy: 0, // Market
      entryPadding: 0.2, // 0.2%
      entryPaddingType: 0, // Prozent
      stopMethod: 2, // ATR
      stopPercent: 5.0,
      atrMult: 2.0, // Standard Swing
      tpMethod: 0, // Risk/Reward
      rrTp1: 1.5,
      rrTp2: 3.0,
      tpPercent1: 5.0,
      tpPercent2: 10.0,
    );
    _saveSettings();
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('theme', _themeMode == ThemeMode.light ? 0 : 1);
    if (_settings.alphaVantageKey != null)
      prefs.setString('av_key', _settings.alphaVantageKey!);
    if (_settings.fmpKey != null) prefs.setString('fmp_key', _settings.fmpKey!);

    // Save Strategy Settings
    prefs.setInt('man_entry_strat', _settings.entryStrategy);
    prefs.setDouble('man_entry_pad', _settings.entryPadding);
    prefs.setInt('man_entry_pad_type', _settings.entryPaddingType);
    prefs.setInt('man_stop_method', _settings.stopMethod);
    prefs.setDouble('man_stop_pct', _settings.stopPercent);
    prefs.setDouble('man_atr_mult', _settings.atrMult);
    prefs.setInt('man_tp_method', _settings.tpMethod);
    prefs.setDouble('man_rr_tp1', _settings.rrTp1);
    prefs.setDouble('man_rr_tp2', _settings.rrTp2);
    prefs.setDouble('man_tp_pct1', _settings.tpPercent1);
    prefs.setDouble('man_tp_pct2', _settings.tpPercent2);
  }
}
