import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart'; // Deine existierenden Models (PriceBar, Signal etc.)
export '../models/models.dart';
import '../models/trade_record.dart';
import 'data_service.dart';
import 'ta_indicators.dart';

class PortfolioService extends ChangeNotifier {
  final DataService _dataService = DataService();

  List<TradeRecord> _trades = [];
  List<TradeRecord> get trades => _trades;

  // Wir nutzen kein festes Startkapital mehr, sondern tracken Investiertes
  double _virtualBalance = 0.0;

  // Bot Einstellungen
  double _botBaseInvest = 100.0; // Standard Invest pro Trade
  int _maxOpenPositions = 5; // Max gleichzeitige Trades
  bool _unlimitedPositions = false;

  // Strategie Einstellungen (neu, damit der Bot nicht hardcoded handelt)
  int _stopMethod = 2; // 0=Donchian, 1=Percent, 2=ATR
  double _stopPercent = 5.0;
  int _entryStrategy = 0; // 0=Market, 1=Pullback (Limit), 2=Breakout (Stop)
  double _entryPadding = 0.2; // Wert für Abstand
  int _entryPaddingType = 0; // 0=Prozent, 1=ATR-Faktor (NEU)
  double _atrMult = 2.0;
  int _tpMethod = 0; // 0=RR, 1=Percent, 2=ATR
  double _rrTp1 = 1.5;
  double _rrTp2 = 3.0;
  double _tpPercent1 = 5.0;
  double _tpPercent2 = 10.0;
  double _tp1SellFraction = 0.5; // NEU: 50% bei TP1 verkaufen

  // Advanced Automation (Neu)
  int _autoIntervalMinutes = 60; // Wie oft scannen?
  double _trailingMult = 1.5; // Wie eng nachziehen?
  bool _dynamicSizing = true; // Einsatz erhöhen bei hohem Score?

  // Routine Scope Settings (Was soll geprüft werden?)
  bool _enableCheckPending = true;
  bool _enableCheckOpen = true;
  bool _enableScanNew = true;

  Timer? _autoTimer;
  bool _autoRun = false;
  bool get autoRun => _autoRun;

  // NEU: Bot Analyse Intervall
  TimeFrame _botTimeFrame = TimeFrame.d1;

  // Default Watchlist (DAX, US Tech, Dow, Euro Stoxx, Crypto)
  static const Map<String, List<String>> _defaultWatchlistByCategory = {
    // DAX 40 (Auswahl)
    "Germany (DAX & MDAX)": [
      "SAP.DE", "SIE.DE", "ALV.DE", "DTE.DE", "BMW.DE", "VOW3.DE", "AIR.DE",
      "BAS.DE", "MUV2.DE", "IFX.DE", "MBG.DE", "DB1.DE", "DHL.DE", "RWE.DE",
      "BAYN.DE", "ADS.DE", "BEI.DE", "EOAN.DE", "HNR1.DE", "DBK.DE", "VNA.DE",
      "SY1.DE", "FRE.DE", "HEI.DE", "MTX.DE", "CBK.DE", "PUM.DE", "ZAL.DE",
      "QIA.DE", "BNR.DE", "SHL.DE", "DTG.DE", "ENR.DE", "HEN3.DE",
      "MRK.DE", "P911.DE", "RHM.DE", "SAT.DE", "SRT3.DE", "1COV.DE", "NEM.DE",
      "AI.DE", "BOSS.DE", "EVT.DE", "FRA.DE", "LEG.DE", "LHAG.DE", "SIEGn.DE"
    ],
    // US Tech (Nasdaq 100 Auswahl)
    "US Tech (Nasdaq)": [
      "AAPL.US", "MSFT.US", "GOOGL.US", "AMZN.US", "NVDA.US", "TSLA.US",
      "META.US", "NFLX.US", "AMD.US", "INTC.US", "CSCO.US", "CMCSA.US",
      "PEP.US", "ADBE.US", "AVGO.US", "TXN.US", "QCOM.US", "TMUS.US",
      "COST.US", "SBUX.US", "AMGN.US", "CHTR.US", "GILD.US", "INTU.US",
      "PYPL.US", "FISV.US", "BKNG.US", "MDLZ.US", "ADP.US", "ISRG.US",
      "ZM.US", "CRWD.US", "SNOW.US", "MRNA.US", "LRCX.US", "MU.US", "KLAC.US",
      "ASML.US", "ADI.US", "EXC.US", "KDP.US", "MAR.US", "MELI.US", "PANW.US",
      "ROST.US", "SIRI.US", "VRSK.US", "WBA.US", "WDAY.US", "XEL.US", "UBER.US",
      "SQ.US", "PLTR.US", "SHOP.US", "RIVN.US"
    ],
    // US Dow / S&P (Auswahl)
    "US Blue Chips (S&P 500)": [
      "JPM.US", "JNJ.US", "V.US", "PG.US", "UNH.US", "HD.US", "MA.US", "DIS.US",
      "BAC.US", "XOM.US", "KO.US", "VZ.US", "CVX.US", "MRK.US", "PFE.US",
      "WMT.US", "T.US", "BA.US", "MCD.US", "NKE.US", "IBM.US", "MMM.US",
      "GE.US", "CAT.US", "GS.US", "AXP.US", "RTX.US", "HON.US", "C.US", "WFC.US",
      "LLY.US", "BRK-B", "DELL.US", "ORCL.US", "CRM.US", "ABT.US", "ACN.US",
      "BLK.US", "BMY.US", "COP.US", "DUK.US", "F.US", "GM.US", "LOW.US", "NEE.US",
      "PM.US", "SRE.US", "SO.US", "TGT.US", "UPS.US"
    ],
    // Europe
    "Europe (ex-DE)": [
      "MC.PA", "OR.PA", "ASML.AS", "PROX.BR", "ABI.BR", "SAN.MC", "ITX.MC",
      "ENEL.MI", "ISP.MI", "NESN.SW", "NOVN.SW", "ROG.SW", "UBSG.SW", "SHEL.L",
      "AZN.L", "HSBA.L", "ULVR.L", "DGE.L", "BATS.L", "GSK.L", "BP.L", "RIO.L",
      "REL.L", "PRU.L", "VOD.L", "BARC.L", "LLOY.L", "TTE.PA", "BNP.PA",
      "KER.PA", "DG.PA", "ACA.PA", "RACE.MI", "ENI.MI", "UCG.MI", "IBE.MC",
      "REP.MC", "PHIA.AS", "INGA.AS", "DSV.CO", "MAERSK-B.CO", "NOVO-B.CO",
      "EQNR.OL", "VOLV-B.ST", "HM-B.ST", "ERIC-B.ST", "NDA-SE.ST"
    ],
    // Japan (Nikkei 225 Auswahl)
    "Japan (Nikkei 225)": [
      "7203.T", "9984.T", "6758.T", "9432.T", "8058.T", "6861.T", "4063.T",
      "8306.T", "6954.T", "7974.T", "6501.T", "9983.T", "8031.T", "4502.T",
      "8001.T", "6367.T", "8766.T", "2914.T", "7267.T", "4901.T", "3382.T",
      "6273.T", "6702.T", "7751.T", "8411.T", "4568.T", "9020.T", "9022.T",
      "5108.T", "8801.T", "8802.T", "7201.T", "7270.T", "6902.T", "6981.T",
      "7202.T", "8053.T", "8316.T", "9201.T", "9735.T"
    ],
    // Crypto
    "Crypto": [
      "BTC-USD", "ETH-USD", "SOL-USD", "XRP-USD", "ADA-USD", "AVAX-USD",
      "DOGE-USD", "DOT-USD", "LINK-USD", "MATIC-USD", "LTC-USD", "BCH-USD",
      "TRX-USD", "SHIB-USD", "LEO-USD", "ATOM-USD", "UNI-USD", "OKB-USD",
      "ETC-USD", "XLM-USD", "XMR-USD", "NEAR-USD", "ALGO-USD", "VET-USD",
      "ICP-USD", "FIL-USD", "HBAR-USD", "CRO-USD", "EOS-USD", "AAVE-USD"
    ],
  };

  // Map für Status: Symbol -> Aktiv (true/false)
  Map<String, bool> _watchListMap = {};
  Map<String, bool> get watchListMap => _watchListMap;

  bool _isScanning = false;
  bool get isScanning => _isScanning;
  String _scanStatus = "";
  bool _cancelRequested = false; // Flag to stop the loop
  String get scanStatus => _scanStatus;
  
  // NEU: Progress Tracking
  int _scanCurrent = 0;
  int _scanTotal = 0;
  int get scanCurrent => _scanCurrent;
  int get scanTotal => _scanTotal;

  // NEU: Top Movers Historie
  List<TopMoverScanResult> _topMoverHistory = [];
  List<TopMoverScanResult> get topMoverHistory => _topMoverHistory;

  // Cache: Wann wurde ein Symbol zuletzt im "Scan New" Modus analysiert?
  final Map<String, DateTime> _lastAnalysisTime = {};

  Map<String, List<String>> get defaultWatchlistByCategory => _defaultWatchlistByCategory;

  double get botBaseInvest => _botBaseInvest;
  int get maxOpenPositions => _maxOpenPositions;
  bool get unlimitedPositions => _unlimitedPositions;

  // Getter für Strategie
  int get stopMethod => _stopMethod;
  double get stopPercent => _stopPercent;
  int get entryStrategy => _entryStrategy;
  double get entryPadding => _entryPadding;
  int get entryPaddingType => _entryPaddingType;
  double get atrMult => _atrMult;
  int get tpMethod => _tpMethod;
  double get rrTp1 => _rrTp1;
  double get rrTp2 => _rrTp2;
  double get tpPercent1 => _tpPercent1;
  double get tpPercent2 => _tpPercent2;
  double get tp1SellFraction => _tp1SellFraction;
  TimeFrame get botTimeFrame => _botTimeFrame;

  int get autoIntervalMinutes => _autoIntervalMinutes;
  double get trailingMult => _trailingMult;
  bool get dynamicSizing => _dynamicSizing;

  bool get enableCheckPending => _enableCheckPending;
  bool get enableCheckOpen => _enableCheckOpen;
  bool get enableScanNew => _enableScanNew;

  void updateBotSettings(double invest, int maxPos, bool unlimited) {
    _botBaseInvest = invest;
    _maxOpenPositions = maxPos;
    _unlimitedPositions = unlimited;
    _savePortfolio();
    notifyListeners();
  }

  void updateStrategySettings({
    required int stopMethod,
    required double stopPercent,
    required int entryStrategy,
    required double entryPadding,
    required int entryPaddingType, // NEU
    required double atrMult,
    required int tpMethod,
    required double rrTp1,
    required double rrTp2,
    required double tpPercent1,
    required double tpPercent2,
    required double tp1SellFraction,
  }) {
    _stopMethod = stopMethod;
    _stopPercent = stopPercent;
    _entryStrategy = entryStrategy;
    _entryPadding = entryPadding;
    _entryPaddingType = entryPaddingType;
    _atrMult = atrMult;
    _tpMethod = tpMethod;
    _rrTp1 = rrTp1;
    _rrTp2 = rrTp2;
    _tpPercent1 = tpPercent1;
    _tpPercent2 = tpPercent2;
    _tp1SellFraction = tp1SellFraction;
    _savePortfolio();
    notifyListeners();
  }

  void updateAdvancedSettings(int interval, double trailMult, bool dynSize) {
    _autoIntervalMinutes = interval;
    _trailingMult = trailMult;
    _dynamicSizing = dynSize;
    _savePortfolio();
    // Timer Neustart falls aktiv, damit Intervall sofort greift
    if (_autoRun) toggleAutoRun(true);
    notifyListeners();
  }

  void updateRoutineFlags({bool? pending, bool? open, bool? scan}) {
    if (pending != null) _enableCheckPending = pending;
    if (open != null) _enableCheckOpen = open;
    if (scan != null) _enableScanNew = scan;
    _savePortfolio();
    notifyListeners();
  }

  void setBotTimeFrame(TimeFrame tf) {
    _botTimeFrame = tf;
    _savePortfolio(); // Save setting
    notifyListeners();
  }

  // Setzt Bot-Einstellungen auf Standardwerte zurück
  void resetBotSettings() {
    _botBaseInvest = 100.0;
    _maxOpenPositions = 5;
    _unlimitedPositions = false;

    _lastAnalysisTime.clear(); // Cache leeren bei Reset
    _stopMethod = 2; // ATR
    _stopPercent = 5.0;
    _entryStrategy = 0; // Market
    _entryPadding = 0.2;
    _entryPaddingType = 0;
    _atrMult = 2.0;
    _tpMethod = 0; // RR
    _rrTp1 = 1.5;
    _rrTp2 = 3.0;
    _tpPercent1 = 5.0;
    _tpPercent2 = 10.0;
    _tp1SellFraction = 0.5;

    _autoIntervalMinutes = 60;
    _trailingMult = 1.5;
    _dynamicSizing = true;
    
    _savePortfolio();
    notifyListeners();
  }

  PortfolioService() {
    _loadPortfolio();
  }

  // --- Auto-Run Steuerung (1h Intervall) ---
  void toggleAutoRun(bool enable) {
    _autoRun = enable;
    _autoTimer?.cancel();
    if (_autoRun) {
      runDailyRoutine(); // Sofort einmal ausführen
      _autoTimer =
          Timer.periodic(Duration(minutes: _autoIntervalMinutes), (timer) {
        runDailyRoutine();
      });
    }
    notifyListeners();
  }

  // --- Hauptfunktion: Markt scannen & Trades managen ---
  Future<void> runDailyRoutine() async {
    if (_isScanning) return;
    _isScanning = true;
    _cancelRequested = false;
    _scanStatus = "Starte Routine...";
    _scanCurrent = 0;
    _scanTotal = 0;
    notifyListeners();

    try {
      // 0. Pending Orders prüfen (Limit Check)
      if (_enableCheckPending) {
        await _checkPendingOrders();
      }

      // 1. Bestehende Trades prüfen (SL/TP Check)
      if (_enableCheckOpen) {
        await _checkOpenPositions();
      }

      // 2. Neue Signale suchen
      if (_enableScanNew) {
        await _scanForNewTrades();
      }

      _scanStatus = "Fertig.";
    } catch (e) {
      _scanStatus = "Fehler: $e";
      debugPrint("❌ [Bot] Critical Error: $e");
    } finally {
      _isScanning = false;
      _savePortfolio();
      notifyListeners();
    }
  }

  // Call this from your UI "Pause" button to stop the current scan
  void cancelRoutine() {
    if (_isScanning) {
      _cancelRequested = true;
      _scanStatus = "Abbruch angefordert...";
      notifyListeners();
    }
  }

  // Helper: Fetch Data in Parallel (Smart Loading)
  Future<Map<String, dynamic>> _fetchDataForSymbol(String symbol, {DateTime? lastScanDate}) async {
    try {
      // Optimierung: Historie (Stooq) nur laden, wenn der letzte Scan länger als 48h her ist.
      // Sonst reicht der Live-Preis (Yahoo).
      bool fetchHistory = true;
      if (lastScanDate != null) {
        final diff = DateTime.now().difference(lastScanDate);
        if (diff.inHours < 48) {
          fetchHistory = false;
        }
      }

      if (!fetchHistory) {
        // debugPrint("ℹ️ [Bot] $symbol: Stooq übersprungen (< 48h). Nur Live-Preis.");
        final livePrice = await _dataService.fetchRegularMarketPrice(symbol);
        return {'bars': <PriceBar>[], 'livePrice': livePrice, 'error': null};
      }

      // Parallel fetch of bars and live price
      final results = await Future.wait([
        _dataService.fetchBars(symbol),
        _dataService.fetchRegularMarketPrice(symbol),
      ]);
      return {
        'bars': results[0] as List<PriceBar>,
        'livePrice': results[1] as double?,
        'error': null
      };
    } catch (e) {
      return {'bars': <PriceBar>[], 'livePrice': null, 'error': e};
    }
  }

  // Prüft, ob Pending Orders ausgeführt werden können (Limit-Verhalten)
  Future<void> _checkPendingOrders() async {
    final pendingTrades =
        _trades.where((t) => t.status == TradeStatus.pending).toList();
    if (pendingTrades.isEmpty) return;

    _scanTotal = pendingTrades.length;
    _scanCurrent = 0;
    _scanStatus = "Prüfe Pending Orders...";
    notifyListeners();

    // Batch processing for speed
    const int chunkSize = 5;
    for (var i = 0; i < pendingTrades.length; i += chunkSize) {
      if (_cancelRequested) break;
      final end = (i + chunkSize < pendingTrades.length) ? i + chunkSize : pendingTrades.length;
      final batch = pendingTrades.sublist(i, end);

      // Parallel Fetching
      final dataResults = await Future.wait(batch.map((t) => _fetchDataForSymbol(t.symbol, lastScanDate: t.lastScanDate)));

      for (var j = 0; j < batch.length; j++) {
        final trade = batch[j];
        final data = dataResults[j];
        
        _scanCurrent++;
        _scanStatus = "Prüfe Pending: ${trade.symbol} ($_scanCurrent/$_scanTotal)";
        notifyListeners();

      try {
        if (data['error'] != null) throw data['error'];

        final bars = data['bars'] as List<PriceBar>;
        final livePrice = data['livePrice'] as double?;
        // Startdatum bestimmen: lastScanDate oder entryDate
        final startDate = trade.lastScanDate ?? trade.entryDate;

        // ATR für Trailing Stop Simulation vorbereiten
        final atrSeries = TA.atr(bars);

        // Relevante Bars filtern (Zeit-Reise)
        final relevantBars = bars.where((b) {
          if (trade.lastScanDate != null) {
            return b.date.isAfter(trade.lastScanDate!);
          }
          // FIX: Stooq Daily Bar des Entry-Tages ignorieren.
          // Vermeidet, dass Limits durch Kurse ausgelöst werden, die VOR der Order-Erstellung am selben Tag lagen.
          final bDate = DateTime(b.date.year, b.date.month, b.date.day);
          final eDate = DateTime(trade.entryDate.year, trade.entryDate.month, trade.entryDate.day);
          return bDate.isAfter(eDate);
        }).toList();

        TradeRecord currentTrade = trade;
        bool tradeUpdated = false;

        // 2. Loop durch Historie
        for (final bar in relevantBars) {
          // --- ENTRY PRÜFUNG ---
          if (currentTrade.status == TradeStatus.pending) {
            bool isLong = currentTrade.takeProfit1 > currentTrade.entryPrice;
            bool isBreakout = currentTrade.entryReasons.contains("Breakout");
            // Fallback: Wenn nicht Breakout, nehmen wir Limit/Pullback an

            double? execPrice;

            if (isBreakout) {
              // STOP ORDER
              if (isLong) {
                // Buy Stop: High >= Entry
                if (bar.high >= currentTrade.entryPrice) {
                  // Gap Schutz: Wenn Open > Entry, dann Open (schlechterer Preis)
                  execPrice = bar.open > currentTrade.entryPrice ? bar.open : currentTrade.entryPrice;
                }
              } else {
                // Sell Stop: Low <= Entry
                if (bar.low <= currentTrade.entryPrice) {
                  // Gap Schutz: Wenn Open < Entry, dann Open (schlechterer Preis)
                  execPrice = bar.open < currentTrade.entryPrice ? bar.open : currentTrade.entryPrice;
                }
              }
            } else {
              // LIMIT ORDER (Pullback)
              if (isLong) {
                // Buy Limit: Low <= Entry
                if (bar.low <= currentTrade.entryPrice) {
                  // Gap Schutz: Wenn Open < Entry, dann Open (besserer Preis)
                  execPrice = bar.open < currentTrade.entryPrice ? bar.open : currentTrade.entryPrice;
                }
              } else {
                // Sell Limit: High >= Entry
                if (bar.high >= currentTrade.entryPrice) {
                  // Gap Schutz: Wenn Open > Entry, dann Open (besserer Preis)
                  execPrice = bar.open > currentTrade.entryPrice ? bar.open : currentTrade.entryPrice;
                }
              }
            }

            if (execPrice != null) {
              // ENTRY HIT!
              // SL/TP anpassen an Gap (Risiko gleich halten)
              final diff = execPrice - currentTrade.entryPrice;
              double newSl = currentTrade.stopLoss + diff;
              final newTp1 = currentTrade.takeProfit1 + diff;
              final newTp2 = currentTrade.takeProfit2 + diff;

              // SAFETY CHECK: SL muss auf der richtigen Seite bleiben
              if (isLong) {
                if (newSl >= execPrice) {
                  newSl = execPrice * 0.99;
                }
              } else {
                if (newSl <= execPrice) {
                  newSl = execPrice * 1.01;
                }
              }

              currentTrade = currentTrade.copyWith(
                status: TradeStatus.open,
                entryExecutionDate: bar.date,
                executionPrice: execPrice,
                entryPrice: execPrice, // Update entryPrice für PnL
                stopLoss: newSl,
                takeProfit1: newTp1,
                takeProfit2: newTp2,
                lastScanDate: bar.date,
              );
              tradeUpdated = true;
              debugPrint("⚡ [Bot] Pending Order Executed (Sim): ${currentTrade.symbol} @ $execPrice");
            }
          }

          // --- EXIT PRÜFUNG (für Open Trades) ---
          if (currentTrade.status == TradeStatus.open) {
            final exitResult = _checkExitConditions(currentTrade, bar);
            if (exitResult != null) {
              currentTrade = exitResult;
              tradeUpdated = true;
              if (currentTrade.status == TradeStatus.closed ||
                  currentTrade.status == TradeStatus.stoppedOut ||
                  currentTrade.status == TradeStatus.takeProfit) {
                break; // Trade beendet
              }
            }

            // --- TRAILING STOP SIMULATION (auch für frisch ausgelöste Pending Orders) ---
            // Wir simulieren das Nachziehen des SL für die restlichen Tage im Loop
            final barIndex = bars.indexOf(bar);
            final currentAtr = (barIndex != -1 && barIndex < atrSeries.length)
                ? (atrSeries[barIndex] ?? bar.close * 0.02)
                : bar.close * 0.02;

            double trailingDist = currentAtr * _trailingMult;
            bool isLong = currentTrade.takeProfit1 > currentTrade.entryPrice;

            if (isLong) {
              double newSl = bar.close - trailingDist;
              if (newSl > currentTrade.stopLoss) {
                // SL nachziehen (nur verbessern)
                currentTrade = currentTrade.copyWith(stopLoss: newSl);
                tradeUpdated = true;
              }
            } else {
              double newSl = bar.close + trailingDist;
              if (newSl < currentTrade.stopLoss) {
                currentTrade = currentTrade.copyWith(stopLoss: newSl);
                tradeUpdated = true;
              }
            }

            // Update lastScanDate
            currentTrade = currentTrade.copyWith(lastScanDate: bar.date);
            tradeUpdated = true;
          }
        } // End Loop Bars

        // 3. Live Check (Fallback für Entry & Exit)
        // Falls Historie (Stooq) nichts ausgelöst hat, prüfen wir den aktuellen Yahoo Live-Preis.
        if (currentTrade.status == TradeStatus.pending && livePrice != null) {
          bool isLong = currentTrade.takeProfit1 > currentTrade.entryPrice;
          bool isBreakout = currentTrade.entryReasons.contains("Breakout");
          bool shouldExecute = false;

          if (isBreakout) {
            // Stop Order
            if (isLong) {
              if (livePrice >= currentTrade.entryPrice) shouldExecute = true;
            } else {
              if (livePrice <= currentTrade.entryPrice) shouldExecute = true;
            }
          } else {
            // Limit Order
            if (isLong) {
              if (livePrice <= currentTrade.entryPrice) shouldExecute = true;
            } else {
              if (livePrice >= currentTrade.entryPrice) shouldExecute = true;
            }
          }

          if (shouldExecute) {
            // Entry zum Live-Preis
            final diff = livePrice - currentTrade.entryPrice;
            double newSl = currentTrade.stopLoss + diff;
            final newTp1 = currentTrade.takeProfit1 + diff;
            final newTp2 = currentTrade.takeProfit2 + diff;

            // SAFETY CHECK: SL muss auf der richtigen Seite bleiben
            if (isLong) {
              if (newSl >= livePrice) newSl = livePrice * 0.99;
            } else {
              if (newSl <= livePrice) newSl = livePrice * 1.01;
            }

            currentTrade = currentTrade.copyWith(
              status: TradeStatus.open,
              entryExecutionDate: DateTime.now(),
              executionPrice: livePrice,
              entryPrice: livePrice,
              stopLoss: newSl,
              takeProfit1: newTp1,
              takeProfit2: newTp2,
              lastScanDate: DateTime.now(),
            );
            tradeUpdated = true;
            debugPrint("⚡ [Bot] Pending Order Executed (LIVE): ${currentTrade.symbol} @ $livePrice");

          }
        }

        if (currentTrade.status == TradeStatus.open && livePrice != null) {
          // Live Exit Check
          final liveBar = PriceBar(
              date: DateTime.now(),
              open: livePrice,
              high: livePrice,
              low: livePrice,
              close: livePrice,
              volume: 0);
          final exitResult = _checkExitConditions(currentTrade, liveBar);
          if (exitResult != null) {
            currentTrade = exitResult;
          } else {
            currentTrade = currentTrade.copyWith(lastPrice: livePrice);
          }
          tradeUpdated = true;
        }

        // Update lastScanDate auf JETZT
        currentTrade = currentTrade.copyWith(lastScanDate: DateTime.now());
        tradeUpdated = true;

        if (tradeUpdated) {
          final index = _trades.indexOf(trade);
          if (index != -1) {
            _trades[index] = currentTrade;
          }
        }
      } catch (e) {
        debugPrint("❌ [Bot] Fehler bei Pending Order ${trade.symbol}: $e");
      }
      } // End Batch Loop
    }
  }

  Future<void> _checkOpenPositions() async {
    final openTrades =
        _trades.where((t) => t.status == TradeStatus.open).toList();
    if (openTrades.isEmpty) return;

    _scanTotal = openTrades.length;
    _scanCurrent = 0;
    _scanStatus = "Prüfe offene Positionen...";
    notifyListeners();

    // Batch processing for speed
    const int chunkSize = 5;
    for (var i = 0; i < openTrades.length; i += chunkSize) {
      if (_cancelRequested) break;
      final end = (i + chunkSize < openTrades.length) ? i + chunkSize : openTrades.length;
      final batch = openTrades.sublist(i, end);

      // Parallel Fetching
      final dataResults = await Future.wait(batch.map((t) => _fetchDataForSymbol(t.symbol, lastScanDate: t.lastScanDate)));

      for (var j = 0; j < batch.length; j++) {
        final trade = batch[j];
        final data = dataResults[j];
        
        _scanCurrent++;
        _scanStatus = "Manage Position: ${trade.symbol} ($_scanCurrent/$_scanTotal)";
        notifyListeners();

      try {
        if (data['error'] != null) throw data['error'];
        final bars = data['bars'] as List<PriceBar>;
        final livePrice = data['livePrice'] as double?;

        // Startdatum: lastScanDate oder entryExecutionDate oder entryDate
        final startDate = trade.lastScanDate ?? trade.entryExecutionDate ?? trade.entryDate;

        // ATR Serie für Trailing Stop Berechnung vorbereiten (einmalig für alle Bars)
        // Wir brauchen das, um in der Loop den korrekten ATR-Wert des jeweiligen Tages zu haben.
        final atrSeries = TA.atr(bars);

        // Relevante Bars filtern
        final relevantBars = bars.where((b) {
          if (trade.lastScanDate != null) {
            return b.date.isAfter(trade.lastScanDate!);
          }
          // FIX: Stooq Daily Bar des Entry-Tages ignorieren.
          // Vermeidet "False Positives" beim SL/TP durch Volatilität, die VOR dem Einstieg am selben Tag stattfand.
          final bDate = DateTime(b.date.year, b.date.month, b.date.day);
          final eDate = DateTime(startDate.year, startDate.month, startDate.day);
          return bDate.isAfter(eDate);
        }).toList();

        TradeRecord currentTrade = trade;
        bool tradeUpdated = false;

        for (final bar in relevantBars) {
          // 1. Prüfe Exit (SL/TP) mit dem aktuellen StopLoss des Trades
          final exitResult = _checkExitConditions(currentTrade, bar);
          if (exitResult != null) {
            currentTrade = exitResult;
            tradeUpdated = true;
            if (currentTrade.status == TradeStatus.closed ||
                currentTrade.status == TradeStatus.stoppedOut ||
                currentTrade.status == TradeStatus.takeProfit) {
              break;
            }
          }

          // 2. Trailing Stop Simulation (SL nachziehen)
          // Wir suchen den ATR Wert passend zu diesem Bar
          // Da relevantBars eine Teilmenge ist, müssen wir den Index im Original 'bars' finden oder mappen.
          // Einfache Variante: Wir nehmen den ATR vom gleichen Index (da TA.atr die gleiche Länge wie bars hat).
          final barIndex = bars.indexOf(bar);
          final currentAtr = (barIndex != -1 && barIndex < atrSeries.length) 
              ? (atrSeries[barIndex] ?? bar.close * 0.02) 
              : bar.close * 0.02;

          double trailingDist = currentAtr * _trailingMult;
          bool isLong = currentTrade.takeProfit1 > currentTrade.entryPrice;

          if (isLong) {
            double newSl = bar.close - trailingDist;
            // Nur nachziehen (verbessern), niemals verschlechtern
            if (newSl > currentTrade.stopLoss) {
              // Begrenzung: SL darf nicht über den aktuellen Preis springen (logisch), 
              // aber hier simulieren wir "End of Day" Anpassung für den NÄCHSTEN Tag.
              currentTrade = currentTrade.copyWith(stopLoss: newSl);
              tradeUpdated = true;
            }
          } else {
            // Short
            double newSl = bar.close + trailingDist;
            if (newSl < currentTrade.stopLoss) {
              currentTrade = currentTrade.copyWith(stopLoss: newSl);
              tradeUpdated = true;
            }
          }

          currentTrade = currentTrade.copyWith(lastScanDate: bar.date);
          tradeUpdated = true;
        }

        // 3. Live Price Update & Exit Check
        if (currentTrade.status == TradeStatus.open) {
          // Fallback: Wenn Live-Preis fehlt, nehmen wir den letzten Close der History
          // Damit PnL nicht 0.00 anzeigt.
          double? priceToUse = livePrice ?? (bars.isNotEmpty ? bars.last.close : null);

          if (livePrice != null) {
            // Nur wenn wir wirklich einen LIVE Preis haben, prüfen wir Exit Conditions "in Echtzeit"
            final liveBar = PriceBar(
                date: DateTime.now(),
                open: livePrice,
                high: livePrice,
                low: livePrice,
                close: livePrice,
                volume: 0);
            final exitResult = _checkExitConditions(currentTrade, liveBar);
            if (exitResult != null) {
              currentTrade = exitResult;
            }
          }
          
          if (priceToUse != null) {
            currentTrade = currentTrade.copyWith(lastPrice: priceToUse);
          }
          tradeUpdated = true;
        }

        currentTrade = currentTrade.copyWith(lastScanDate: DateTime.now());
        tradeUpdated = true;

        if (tradeUpdated) {
          final index = _trades.indexWhere((t) => t.id == trade.id);
          if (index != -1) _trades[index] = currentTrade;
        }
      } catch (e) {
        debugPrint("❌ [Bot] Fehler beim Check von ${trade.symbol}: $e");
      }
      } // End Batch Loop
    }
    _savePortfolio();
  }

  // Helper für Exit-Logik (SL/TP)
  TradeRecord? _checkExitConditions(TradeRecord trade, PriceBar bar) {
    bool isLong = trade.takeProfit1 > trade.entryPrice;
    bool slHit = false;
    bool tp1Hit = false;
    bool tp2Hit = false;

    if (isLong) {
      if (bar.low <= trade.stopLoss) slHit = true;
      if (bar.high >= trade.takeProfit2) tp2Hit = true;
      if (!trade.tp1Hit && bar.high >= trade.takeProfit1) tp1Hit = true;
    } else {
      if (bar.high >= trade.stopLoss) slHit = true;
      if (bar.low <= trade.takeProfit2) tp2Hit = true;
      if (!trade.tp1Hit && bar.low <= trade.takeProfit1) tp1Hit = true;
    }

    // Konfliktlösung: Worst Case First (SL vor TP am selben Tag)
    if (slHit && tp2Hit) {
      tp2Hit = false;
      tp1Hit = false;
    }

    if (slHit) {
      final pnl = _calcPnL(trade, trade.stopLoss);
      _virtualBalance += (trade.entryPrice * trade.quantity) + pnl;
      return trade.copyWith(
        status: TradeStatus.stoppedOut,
        exitDate: bar.date,
        closeExecutionDate: bar.date,
        exitPrice: trade.stopLoss,
        realizedPnL: trade.realizedPnL + pnl,
      );
    } else if (tp2Hit) {
      final pnl = _calcPnL(trade, trade.takeProfit2);
      _virtualBalance += (trade.entryPrice * trade.quantity) + pnl;
      return trade.copyWith(
        status: TradeStatus.takeProfit,
        exitDate: bar.date,
        closeExecutionDate: bar.date,
        exitPrice: trade.takeProfit2,
        realizedPnL: trade.realizedPnL + pnl,
      );
    } else if (tp1Hit) {
      final qtySell = trade.quantity * _tp1SellFraction;
      final pnl = _calcPnL(trade, trade.takeProfit1, qty: qtySell);
      _virtualBalance += (trade.entryPrice * qtySell) + pnl;
      return trade.copyWith(
        tp1Hit: true,
        quantity: trade.quantity - qtySell,
        realizedPnL: trade.realizedPnL + pnl,
        stopLoss: trade.entryPrice, // Break Even
      );
    }
    return null; // Keine Änderung
  }

  double _calcPnL(TradeRecord t, double exitPrice, {double? qty}) {
    double q = qty ?? t.quantity;
    // Nutze executionPrice falls vorhanden
    double entry = t.executionPrice ?? t.entryPrice;
    bool isLong = t.takeProfit1 > t.entryPrice;
    return isLong ? (exitPrice - entry) * q : (entry - exitPrice) * q;
  }

  Future<void> _scanForNewTrades() async {
    // Nur aktive Symbole scannen
    final activeSymbols =
        _watchListMap.entries.where((e) => e.value).map((e) => e.key).toList();

    _scanTotal = activeSymbols.length;
    _scanCurrent = 0;

    for (var symbol in activeSymbols) {
      if (_cancelRequested) {
        _scanStatus = "Scan abgebrochen.";
        break;
      }
      _scanCurrent++;

      // OPTIMIERUNG: Überspringe Symbol, wenn es kürzlich erst gescannt wurde
      // Wir nutzen das _autoIntervalMinutes als Referenz.
      if (_lastAnalysisTime.containsKey(symbol)) {
        final lastScan = _lastAnalysisTime[symbol]!;
        if (DateTime.now().difference(lastScan).inMinutes < _autoIntervalMinutes) {
          continue; // Überspringen, Daten sind noch "frisch genug"
        }
      }

      try {
        _scanStatus = "Analysiere $symbol ($_scanCurrent/$_scanTotal)...";
        notifyListeners();

        // Check Max Positions
        if (!_unlimitedPositions) {
          int openCount =
              _trades.where((t) => t.status == TradeStatus.open || t.status == TradeStatus.pending).length;
          if (openCount >= _maxOpenPositions) {
            _scanStatus =
                "Max Positionen ($openCount/$_maxOpenPositions) erreicht.";

            debugPrint("⚠️ [Bot] Max Positionen erreicht ($openCount/$_maxOpenPositions).");
            notifyListeners(); // UI updaten
            break; // Keine neuen Trades mehr
          }
        }

        // 1. Daten laden
        final bars = await _dataService.fetchBars(symbol, interval: _botTimeFrame);
        
        // Zeitstempel aktualisieren (damit wir nicht sofort wieder Stooq abrufen)
        _lastAnalysisTime[symbol] = DateTime.now();

        if (bars.length < 50) continue;

        // 2. Analyse durchführen
        final signal = analyzeStock(bars);

        if (signal != null &&
            (signal.type.contains("Buy") || signal.type.contains("Sell"))) {
          // Prüfen, ob wir den Trade schon offen haben
          bool alreadyOpen = _trades
              .any((t) => t.symbol == symbol && t.status == TradeStatus.open);
          if (!alreadyOpen) {
            // NEU: Entry-Preis Berechnung
            // 1. Yahoo Live Preis (aktuell)
            // 2. Fallback: Stooq CSV (bars.last.close), wenn länger nicht gescannt/kein Live-Preis
            double executionPrice;
            if (_entryStrategy == 0) {
              // Market: Versuche Live-Preis, sonst Stooq Close
              final livePrice =
                  await _dataService.fetchRegularMarketPrice(symbol);
              executionPrice = livePrice ?? bars.last.close;
            } else {
              // Pending (Pullback/Breakout): Wir nutzen den berechneten Entry aus dem Signal
              executionPrice = signal.entryPrice;
            }
            _executeBuy(symbol, bars.last, signal, executionPrice);
          }
        }

        // Kurze Pause um API Rate Limits zu schonen
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        // Fehler bei einem Symbol soll nicht den ganzen Bot stoppen
        debugPrint("❌ [Bot] Fehler bei Scan von $symbol: $e");
        continue;
      }
    }
  }

  // Echte Strategie-Logik (portiert aus AppProvider)
  TradeSignal? analyzeStock(List<PriceBar> bars) {
    if (bars.isEmpty) return null;

    final closes = bars.map((b) => b.close).toList();

    // 1. Indikatoren berechnen
    final ema20 = TA.ema(closes, 20);
    final rsi = TA.rsi(closes);
    final macdOut = TA.macd(closes);
    final atr = TA.atr(bars);
    final st = TA.supertrend(bars);
    final stoch = TA.stochastic(bars);
    final obv = TA.obv(bars);
    final pattern = TA.detectPattern(bars);
    final donchian = TA.donchian(bars); // Neu für SL Methode 0
    final adx = TA.calcAdx(bars); // Neu für Snapshot
    final squeeze = TA.squeezeFlags(bars); // Neu für Snapshot
    // NEU: Erweiterte Analysen
    final ichimokuOut = TA.ichimoku(bars);
    final divergenceResult = TA.detectDivergences(closes, rsi);

    // Letzte Werte extrahieren
    final lastPrice = closes.last;
    final lastRsi = rsi.last ?? 50;
    final lastMacdHist = macdOut.hist.last ?? 0;
    final lastEma20 = ema20.last ?? lastPrice;
    final lastAtr = atr.last ?? (lastPrice * 0.02);
    final lastStBull = st.bull.isNotEmpty ? st.bull.last : false;
    final lastStochK = stoch.k.last ?? 50;
    final lastObv = obv.isNotEmpty ? (obv.last ?? 0) : 0.0;
    final lastAdx = adx.adx.isNotEmpty ? (adx.adx.last ?? 0) : 0.0;
    final isSqueeze = squeeze.isNotEmpty ? squeeze.last : false;

    // NEU: Ichimoku Werte
    final lastTenkan = ichimokuOut.tenkan.last;
    final lastKijun = ichimokuOut.kijun.last;
    const int spanOffset = 26;
    final relevantSpanA = bars.length > spanOffset
        ? ichimokuOut.spanA[bars.length - 1 - spanOffset]
        : null;
    final relevantSpanB = bars.length > spanOffset ? ichimokuOut.spanB[bars.length - 1 - spanOffset] : null;

    // Donchian Werte extrahieren
    double lastDonchianLo = lastPrice * 0.95;
    for (final v in donchian.lo.reversed) {
      if (v != null) {
        lastDonchianLo = v;
        break;
      }
    }

    double lastDonchianUp = lastPrice * 1.05;
    for (final v in donchian.up.reversed) {
      if (v != null) {
        lastDonchianUp = v;
        break;
      }
    }

    // OBV Trend Check
    double prevObv = 0;
    if (obv.length > 5) prevObv = obv[obv.length - 5] ?? 0;

    // 2. Scoring (0 bis 100)
    int score = 50;
    List<String> reasons = [];

    // A. Trend & Struktur
    if (lastPrice > lastEma20) {
      score += 10;
      reasons.add("Kurs > EMA20");
    } else {
      score -= 10;
    }
    if (lastStBull) {
      score += 10;
      reasons.add("Supertrend Bullish");
    } else {
      score -= 10;
    }

    // B. Momentum & ADX Filter (Smart Logic)
    bool strongTrend = lastAdx > 25;

    if (strongTrend) {
      // Im starken Trend ist RSI > 70 okay (Momentum)
      if (lastRsi > 50 && lastRsi < 80) {
        score += 5;
        reasons.add("RSI Momentum");
      } else if (lastRsi >= 80) {
        score -= 10;
        reasons.add("RSI Überhitzt");
      } else if (lastRsi < 40) {
        score -= 5;
      }
    } else {
      // Range: RSI > 70 ist Sell
      if (lastRsi > 70) {
        score -= 15;
        reasons.add("RSI Überkauft (Range)");
      } else if (lastRsi < 30) {
        score += 15;
        reasons.add("RSI Überverkauft (Range)");
      }
    }

    // Stochastic
    if (lastStochK < 20) {
      score += 10;
      reasons.add("Stoch Oversold");
    } else if (lastStochK > 80) {
      score -= (strongTrend ? 5 : 10);
    }

    // C. Volumen & Squeeze
    if (lastObv > prevObv) {
      score += 5;
      reasons.add("OBV Steigend");
    } else {
      score -= 5;
    }
    if (isSqueeze) {
      score += 10;
      reasons.add("Squeeze Aktiv");
    }
    if (lastMacdHist > 0) {
      score += 5;
      reasons.add("MACD Positiv");
    } else {
      score -= 5;
    }

    // D. Pattern
    if (pattern.contains("Bullish") || pattern.contains("Hammer")) {
      score += 15;
      reasons.add(pattern);
    }
    if (pattern.contains("Bearish") || pattern.contains("Shooting")) {
      score -= 15;
      reasons.add(pattern);
    }

    // E. Ichimoku Cloud
    bool isCloudBullish = false;
    if (relevantSpanA != null && relevantSpanB != null) {
      // Preis über der Wolke (bullish)
      if (lastPrice > relevantSpanA && lastPrice > relevantSpanB) {
        score += 10;
        reasons.add("Kurs über Wolke");
        isCloudBullish = true;
      }
      // Preis unter der Wolke (bearish)
      else if (lastPrice < relevantSpanA && lastPrice < relevantSpanB) {
        score -= 10;
        reasons.add("Kurs unter Wolke");
      }
    }

    bool isCrossBullish = false;
    if (lastTenkan != null && lastKijun != null) {
      if (lastTenkan > lastKijun) {
        score += 5;
        reasons.add("Tenkan > Kijun");
        isCrossBullish = true;
      } else {
        score -= 5;
      }
    }

    // F. Divergenzen (sehr starkes Signal)
    String divergenceType = "none";
    // Prüfe die letzten 3 Kerzen auf ein Divergenz-Pivot
    for (int i = 1; i <= 3; i++) {
      int idx = bars.length - i;
      if (divergenceResult.bullishIndices.contains(idx)) {
        score += 20;
        reasons.add("Bullish Divergenz");
        divergenceType = "bullish";
        break;
      }
      if (divergenceResult.bearishIndices.contains(idx)) {
        score -= 20;
        reasons.add("Bearish Divergenz");
        divergenceType = "bearish";
        break;
      }
    }

    score = score.clamp(0, 100);

    // 3. Signal Typ bestimmen
    String type = "Neutral";
    if (score >= 80)
      type = "Strong Buy";
    else if (score >= 60)
      type = "Buy";
    else if (score <= 40) type = "Sell";

    if (type == "Neutral") return null;

    // Define isLong here so it can be used for Entry Strategy logic below
    bool isLong = type.contains("Buy");

    // 4. SL / TP Berechnung (Jetzt konfigurierbar!)
    // Entry Berechnung basierend auf Strategie
    double entry = lastPrice;

    // Padding berechnen (Prozent oder ATR)
    double paddingVal = 0.0;
    if (_entryPaddingType == 0) {
      // Prozentual
      paddingVal = lastPrice * (_entryPadding / 100);
    } else {
      // ATR Faktor
      paddingVal = lastAtr * _entryPadding;
    }

    if (_entryStrategy == 1) {
      // Pullback (Limit)
      if (isLong) {
        entry = lastPrice - paddingVal; // Buy Limit unter Close
      } else {
        entry = lastPrice + paddingVal; // Sell Limit über Close
      }
    } else if (_entryStrategy == 2) {
      // Breakout (Stop)
      if (isLong) {
        entry = bars.last.high + paddingVal; // Buy Stop über High
      } else {
        entry = bars.last.low - paddingVal; // Sell Stop unter Low
      }
    }
    // Bei Market (_entryStrategy == 0) bleibt entry = lastPrice

    // isLong wurde oben schon definiert für Entry-Berechnung, hier nutzen wir es weiter
    double sl, tp1, tp2;

    // A. Stop Loss
    // WICHTIG: SL Berechnung basiert auf dem geplanten Entry!
    // Wir berechnen SL relativ zum Close (lastPrice) und schieben ihn dann mit.
    if (isLong) {
      if (_stopMethod == 0)
        sl = lastDonchianLo;
      else if (_stopMethod == 1)
        sl = lastPrice * (1 - _stopPercent / 100);
      else
        sl = lastPrice - (_atrMult * lastAtr);

      // SAFETY CHECK: SL muss zwingend unter Entry liegen (Long)
      // Falls Berechnung (z.B. Donchian) SL >= Entry ergibt, erzwingen wir 1% Abstand
      if (sl >= entry) sl = entry * 0.99;
    } else {
      if (_stopMethod == 0)
        sl = lastDonchianUp;
      else if (_stopMethod == 1)
        sl = lastPrice * (1 + _stopPercent / 100);
      else
        sl = lastPrice + (_atrMult * lastAtr);

      // SAFETY CHECK: SL muss zwingend über Entry liegen (Short)
      if (sl <= entry) sl = entry * 1.01;
    }

    // Wenn wir den Entry verschieben (Pullback/Breakout), müssen wir den SL auch relativ dazu sehen?
    // Nein, SL ist oft ein technisches Level (Donchian Low). Das bleibt gleich, egal wo wir einsteigen.
    // ABER: Das Risiko ändert sich.

    double risk = (entry - sl).abs();

    // B. Take Profit
    // TP berechnet sich oft vom Entry aus (CRV)
    if (isLong) {
      if (_tpMethod == 1) {
        // Prozentual
        tp1 = entry * (1 + _tpPercent1 / 100);
        tp2 = entry * (1 + _tpPercent2 / 100);
      } else if (_tpMethod == 2) {
        // ATR Ziel
        final atrRisk = lastAtr * _atrMult;
        tp1 = entry + (atrRisk * _rrTp1);
        tp2 = entry + (atrRisk * _rrTp2);
      } else {
        // CRV (Default)
        tp1 = entry + (risk * _rrTp1);
        tp2 = entry + (risk * _rrTp2);
      }
    } else {
      if (_tpMethod == 1) {
        // Prozentual
        tp1 = entry * (1 - _tpPercent1 / 100);
        tp2 = entry * (1 - _tpPercent2 / 100);
      } else if (_tpMethod == 2) {
        // ATR Ziel
        final atrRisk = lastAtr * _atrMult;
        tp1 = entry - (atrRisk * _rrTp1);
        tp2 = entry - (atrRisk * _rrTp2);
      } else {
        // CRV
        tp1 = entry - (risk * _rrTp1);
        tp2 = entry - (risk * _rrTp2);
      }
    }

    double rrFactor = risk == 0 ? 0 : (tp2 - entry).abs() / risk;

    // Calculate TP percentages
    double? tp1Percent, tp2Percent;
    if (isLong) {
      tp1Percent = ((tp1 - entry) / entry) * 100;
      tp2Percent = ((tp2 - entry) / entry) * 100;
    } else {
      tp1Percent = ((entry - tp1) / entry) * 100;
      tp2Percent = ((entry - tp2) / entry) * 100;
    }

    // Snapshot Daten für Detailansicht
    final snapshot = {
      'rsi': lastRsi,
      'ema20': lastEma20,
      'price': lastPrice,
      'macdHist': lastMacdHist,
      'stBull': lastStBull,
      'stochK': lastStochK,
      'obv': lastObv,
      'adx': lastAdx,
      'squeeze': isSqueeze,
      // NEU: Erweiterte Analysen im Snapshot
      'ichimoku_cloud_bull': isCloudBullish,
      'ichimoku_cross_bull': isCrossBullish,
      'divergence': divergenceType,
    };

    return TradeSignal(
        type: type,
        entryPrice: entry,
        stopLoss: sl,
        takeProfit1: tp1,
        takeProfit2: tp2,
        riskRewardRatio: rrFactor,
        score: score,
        reasons: reasons,
        chartPattern: pattern,
        tp1Percent: tp1Percent,
        tp2Percent: tp2Percent,
        indicatorValues: snapshot);
  }

  void _executeBuy(String symbol, PriceBar lastBar, TradeSignal signal,
      double executionPrice) {
    // Money Management: Gewichtung nach Score
    double baseInvest = _botBaseInvest;
    double multiplier = 1.0;

    // Je stärker das Signal, desto mehr Einsatz
    if (_dynamicSizing) {
      if (signal.score >= 80 || signal.score <= 20)
        multiplier = 2.0; // Doppelt bei Strong Signal
      else if (signal.score >= 70 || signal.score <= 30) multiplier = 1.5;
    }
    double positionSize = baseInvest * multiplier;
    double qty = positionSize / executionPrice;

    // NEU: SL/TP an den tatsächlichen Ausführungspreis anpassen, um das Risiko beizubehalten.
    // Bei Market Order: executionPrice ist Live-Preis, signal.entryPrice war Close. Differenz anpassen.
    // Bei Pending Order: executionPrice ist gleich signal.entryPrice. Differenz ist 0.
    final priceDifference = executionPrice - signal.entryPrice;
    double adjustedStopLoss = signal.stopLoss + priceDifference;
    final adjustedTakeProfit1 = signal.takeProfit1 + priceDifference;
    final adjustedTakeProfit2 = signal.takeProfit2 + priceDifference;

    // SAFETY CHECK AUCH BEI EXECUTION:
    // Durch Gaps oder Rechenungenauigkeiten darf der SL nicht auf die falsche Seite rutschen.
    bool isLong = signal.type.contains("Buy");
    if (isLong) {
      if (adjustedStopLoss >= executionPrice) {
        adjustedStopLoss = executionPrice * 0.99;
        debugPrint("⚠️ [Bot] SL Korrektur bei Order (Long): SL >= Entry.");
      }
    } else {
      if (adjustedStopLoss <= executionPrice) {
        adjustedStopLoss = executionPrice * 1.01;
        debugPrint("⚠️ [Bot] SL Korrektur bei Order (Short): SL <= Entry.");
      }
    }

    // Status bestimmen
    TradeStatus initialStatus = TradeStatus.open;
    if (_entryStrategy == 1) initialStatus = TradeStatus.pending; // Pullback
    if (_entryStrategy == 2) initialStatus = TradeStatus.pending; // Breakout
    // Bei Market (_entryStrategy == 0) bleibt es TradeStatus.open

    if (_entryStrategy != 0)
      signal.reasons
          .add("Strategy: ${_entryStrategy == 1 ? 'Pullback' : 'Breakout'}");

    // Bot Einstellungen speichern
    final settingsSnapshot = {
      'entryStrategy': _entryStrategy,
      'entryPadding': _entryPadding,
      'entryPaddingType': _entryPaddingType,
      'stopMethod': _stopMethod,
      'stopPercent': _stopPercent,
      'atrMult': _atrMult,
      'tpMethod': _tpMethod,
      'rrTp1': _rrTp1,
      'rrTp2': _rrTp2,
      'tpPercent1': _tpPercent1,
      'tpPercent2': _tpPercent2,
      'tp1SellFraction': _tp1SellFraction,
    };

    // Merge mit Indicator Snapshot
    final fullSnapshot =
        Map<String, dynamic>.from(signal.indicatorValues ?? {});
    fullSnapshot.addAll(settingsSnapshot);

    final newTrade = TradeRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      symbol: symbol,
      entryDate: lastBar.date, // Das Datum des Signals
      entryPrice: executionPrice, // Der tatsächliche Ausführungspreis
      quantity: qty,
      // Angepasste Werte verwenden
      stopLoss: adjustedStopLoss,
      takeProfit1: adjustedTakeProfit1,
      takeProfit2: adjustedTakeProfit2,
      status: initialStatus, // WICHTIG: Open bei Market, Pending bei Limit/Stop
      entryScore: signal.score,
      entryReasons: signal.reasons.join(", "),
      entryPattern: signal.chartPattern,
      aiAnalysisSnapshot: fullSnapshot,
      botTimeFrame: _botTimeFrame,
      // NEU: Felder für Historie befüllen
      executionPrice: executionPrice,
      entryExecutionDate: initialStatus == TradeStatus.open ? DateTime.now() : null,
      lastScanDate: DateTime.now(),
    );

    _trades.add(newTrade);
    _virtualBalance -= (executionPrice * qty); // Geld abziehen

    debugPrint("🛒 [Bot] ORDER ERSTELLT (${initialStatus.name}): $symbol @ $executionPrice");
    _savePortfolio(); // Sofort speichern
  }

  // NEU: Logik für Teilverkäufe bei TP1
  void _handleTakeProfit1(TradeRecord trade, double price, DateTime date) {
    if (trade.tp1Hit) return; // Bereits ausgeführt

    final double quantityToSell = trade.quantity * _tp1SellFraction;
    final double remainingQuantity = trade.quantity - quantityToSell;

    bool isLong = trade.takeProfit1 > trade.entryPrice;
    double pnlFromPartialClose;
    if (isLong) {
      pnlFromPartialClose = (price - trade.entryPrice) * quantityToSell;
    } else {
      pnlFromPartialClose = (trade.entryPrice - price) * quantityToSell;
    }

    trade.realizedPnL += pnlFromPartialClose;
    _virtualBalance += (trade.entryPrice * quantityToSell) + pnlFromPartialClose; // Kapital + Gewinn zurückbuchen
    trade.quantity = remainingQuantity; // Positionsgröße reduzieren
    trade.tp1Hit = true;
    trade.stopLoss = trade.entryPrice; // SL auf Break-Even setzen

    debugPrint("💰 [Bot] TP1 HIT: ${trade.symbol} | Sold ${_tp1SellFraction * 100}% | PnL: ${pnlFromPartialClose.toStringAsFixed(2)}");
  }

  void _closeTrade(
      TradeRecord trade, double price, TradeStatus reason, DateTime exitDate) {
    trade.status = reason;
    trade.exitDate = exitDate;
    trade.exitPrice = price;

    // PnL Berechnung (unterscheidet Long/Short)
    bool isLong = trade.takeProfit1 > trade.entryPrice;
    double pnlForThisClose;
    if (isLong) {
      pnlForThisClose = (price - trade.entryPrice) * trade.quantity;
    } else {
      // Short: Gewinn wenn Entry > Exit
      pnlForThisClose = (trade.entryPrice - price) * trade.quantity;
    }
    trade.realizedPnL += pnlForThisClose;

    // Kapital zurückbuchen (Invest für diesen Teil + PnL für diesen Teil)
    _virtualBalance += (trade.entryPrice * trade.quantity) + pnlForThisClose;
    debugPrint("💵 [Bot] TRADE CLOSED: ${trade.symbol} | PnL: ${trade.realizedPnL.toStringAsFixed(2)}");
    _savePortfolio(); // Sofort speichern
  }

  // Trade manuell löschen
  void deleteTrade(String id) {
    _trades.removeWhere((t) => t.id == id);
    _savePortfolio();
    notifyListeners();
  }

  // Alles zurücksetzen
  void resetPortfolio() {
    _trades.clear();
    _virtualBalance = 0.0;
    _autoTimer?.cancel();
    _autoRun = false;
    _savePortfolio();
    notifyListeners();
  }

  // --- Watchlist Management ---
  void toggleWatchlistSymbol(String symbol, bool isActive) {
    _watchListMap[symbol] = isActive;
    _savePortfolio();
    notifyListeners();
  }

  void addWatchlistSymbol(String symbol) {
    _watchListMap[symbol.toUpperCase()] = true;
    _savePortfolio();
    notifyListeners();
  }

  void removeWatchlistSymbol(String symbol) {
    _watchListMap.remove(symbol);
    _savePortfolio();
    notifyListeners();
  }

  // --- Top Movers Historie ---
  void addTopMoversToHistory(List<dynamic> topLong, List<dynamic> topShort, TimeFrame tf) {
    final combined = [...topLong, ...topShort];
    final records = combined.map((mover) {
      return TopMoverRecord(
        symbol: mover.symbol,
        score: mover.signal.score,
        priceAtScan: mover.signal.entryPrice,
        signalType: mover.signal.type.contains("Buy") ? "Buy" : "Sell",
      );
    }).toList();

    final result = TopMoverScanResult(scanDate: DateTime.now(), timeFrame: tf, topMovers: records);
    _topMoverHistory.insert(0, result); // Neueste zuerst
    if (_topMoverHistory.length > 20) _topMoverHistory = _topMoverHistory.sublist(0, 20); // Limit auf 20 Scans
    _savePortfolio();
    notifyListeners();
  }

  // --- Persistenz ---
  Future<void> _savePortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(_trades.map((t) => t.toJson()).toList());
    await prefs.setString('bot_trades', jsonStr);
    await prefs.setDouble('bot_balance', _virtualBalance);
    await prefs.setDouble('bot_invest', _botBaseInvest);
    await prefs.setInt('bot_max_pos', _maxOpenPositions);
    await prefs.setBool('bot_unlimited', _unlimitedPositions);
    // Strategie speichern
    await prefs.setInt('bot_stop_method', _stopMethod);
    await prefs.setDouble('bot_stop_percent', _stopPercent);
    await prefs.setInt('bot_entry_strategy', _entryStrategy);
    await prefs.setDouble('bot_entry_padding', _entryPadding);
    await prefs.setInt('bot_entry_padding_type', _entryPaddingType); // NEU
    await prefs.setDouble('bot_atr_mult', _atrMult);
    await prefs.setInt('bot_tp_method', _tpMethod);
    await prefs.setDouble('bot_rr_tp1', _rrTp1);
    await prefs.setDouble('bot_rr_tp2', _rrTp2);
    await prefs.setDouble('bot_tp_percent1', _tpPercent1);
    await prefs.setDouble('bot_tp_percent2', _tpPercent2);
    await prefs.setDouble('bot_tp1_sell_fraction', _tp1SellFraction);
    await prefs.setInt('bot_timeframe', _botTimeFrame.index);
    await prefs.setString('bot_watchlist_map', jsonEncode(_watchListMap));
    await prefs.setInt('bot_auto_interval', _autoIntervalMinutes);
    await prefs.setDouble('bot_trailing_mult', _trailingMult);
    await prefs.setBool('bot_dynamic_sizing', _dynamicSizing);
    await prefs.setBool('bot_enable_pending', _enableCheckPending);
    await prefs.setBool('bot_enable_open', _enableCheckOpen);
    await prefs.setBool('bot_enable_scan', _enableScanNew);

    final String historyJson = jsonEncode(_topMoverHistory.map((h) => h.toJson()).toList());
    await prefs.setString('bot_top_mover_history', historyJson);
  }

  Future<void> _loadPortfolio() async {
    final prefs = await SharedPreferences.getInstance();
    _virtualBalance = prefs.getDouble('bot_balance') ?? 0.0;
    _botBaseInvest = prefs.getDouble('bot_invest') ?? 100.0;
    _maxOpenPositions = prefs.getInt('bot_max_pos') ?? 5;
    _unlimitedPositions = prefs.getBool('bot_unlimited') ?? false;

    _stopMethod = prefs.getInt('bot_stop_method') ?? 2;
    _stopPercent = prefs.getDouble('bot_stop_percent') ?? 5.0;
    _entryStrategy = prefs.getInt('bot_entry_strategy') ?? 0;
    _entryPadding = prefs.getDouble('bot_entry_padding') ?? 0.2;
    _entryPaddingType = prefs.getInt('bot_entry_padding_type') ?? 0; // NEU
    _atrMult = prefs.getDouble('bot_atr_mult') ?? 2.0;
    _tpMethod = prefs.getInt('bot_tp_method') ?? 0;
    _rrTp1 = prefs.getDouble('bot_rr_tp1') ?? 1.5;
    _rrTp2 = prefs.getDouble('bot_rr_tp2') ?? 3.0;
    _tpPercent1 = prefs.getDouble('bot_tp_percent1') ?? 5.0;
    _tpPercent2 = prefs.getDouble('bot_tp_percent2') ?? 10.0;
    _tp1SellFraction = prefs.getDouble('bot_tp1_sell_fraction') ?? 0.5;
    _botTimeFrame = TimeFrame.values[prefs.getInt('bot_timeframe') ?? TimeFrame.d1.index];

    _autoIntervalMinutes = prefs.getInt('bot_auto_interval') ?? 60;
    _trailingMult = prefs.getDouble('bot_trailing_mult') ?? 1.5;
    _dynamicSizing = prefs.getBool('bot_dynamic_sizing') ?? true;
    _enableCheckPending = prefs.getBool('bot_enable_pending') ?? true;
    _enableCheckOpen = prefs.getBool('bot_enable_open') ?? true;
    _enableScanNew = prefs.getBool('bot_enable_scan') ?? true;

    final String? jsonStr = prefs.getString('bot_trades');
    if (jsonStr != null) {
      final List decoded = jsonDecode(jsonStr);
      _trades = decoded.map((x) => TradeRecord.fromJson(x)).toList();
    }

    final String? wlStr = prefs.getString('bot_watchlist_map');
    if (wlStr != null) {
      _watchListMap = Map<String, bool>.from(jsonDecode(wlStr));
    } else {
      // Init defaults
      _defaultWatchlistByCategory.values.forEach((symbolList) {
        for (var symbol in symbolList) {
          _watchListMap[symbol] = true;
        }
      });
    }

    final String? historyJson = prefs.getString('bot_top_mover_history');
    if (historyJson != null) {
      final List decoded = jsonDecode(historyJson);
      _topMoverHistory = decoded.map((x) => TopMoverScanResult.fromJson(x)).toList();
    }
    notifyListeners();
  }

  // Getter für UI Stats
  double get totalInvested {
    return _trades
        .where((t) => t.status == TradeStatus.open)
        .fold(0.0, (sum, t) => sum + (t.entryPrice * t.quantity));
  }

  double get totalRealizedPnL {
    return _trades
        .where((t) => t.status != TradeStatus.open)
        .fold(0.0, (sum, t) => sum + t.realizedPnL);
  }

  double get totalUnrealizedPnL {
    return _trades
        .where((t) => t.status == TradeStatus.open)
        .fold(0.0, (sum, t) => sum + t.calcUnrealizedPnL(t.lastPrice ?? t.entryPrice));
  }
}
