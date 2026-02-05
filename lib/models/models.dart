class PriceBar {
  final DateTime date;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
  PriceBar(
      {required this.date,
      required this.open,
      required this.high,
      required this.low,
      required this.close,
      required this.volume});
}

enum TimeFrame {
  m15, // 15 Minuten
  h1,  // 1 Stunde
  h4,  // 4 Stunden
  d1,  // 1 Tag (Standard)
  w1,  // 1 Woche
}

// Hilfsfunktion um es für die Yahoo API lesbar zu machen
extension TimeFrameExtension on TimeFrame {
  String get apiString {
    switch (this) {
      case TimeFrame.m15: return '15m';
      case TimeFrame.h1: return '60m'; // oder '1h' je nach API
      case TimeFrame.h4: return '60m'; // Yahoo hat kein echtes 4h, man muss oft 1h nehmen und aggregieren, aber für den Anfang reicht 1h
      case TimeFrame.d1: return '1d';
      case TimeFrame.w1: return '1wk';
    }
  }
  
  String get label {
    switch (this) {
      case TimeFrame.m15: return '15 Min';
      case TimeFrame.h1: return '1 Std';
      case TimeFrame.h4: return '4 Std';
      case TimeFrame.d1: return 'Tag';
      case TimeFrame.w1: return 'Woche';
    }
  }
}

enum ChartRange { week1, month1, quarter1, year1, year2, year3, year5 }

class NewsItem {
  final String title;
  final String link;
  final String pubDate;
  NewsItem({required this.title, required this.link, required this.pubDate});
}

class FundamentalData {
  final String? sector;
  final String? industry;
  final double? peRatio; // KGV
  final double? pbRatio; // KBV
  final double? dividendYield; // Dividende %
  final double? marketCap;
  final double? forwardPe;
  final String? currency;

  FundamentalData(
      {this.sector,
      this.industry,
      this.peRatio,
      this.pbRatio,
      this.dividendYield,
      this.marketCap,
      this.forwardPe,
      this.currency});
}

class FmpData {
  final String symbol;
  final String companyName;
  final String description;
  final String sector;
  final String industry;
  final double price;
  final double marketCap;
  final double beta;
  final bool isEtf;

  // Erweiterte Profile Daten (Stable Endpoint)
  final String? website;
  final String? ceo;
  final String? exchange;
  final String? country;
  final String? image;
  final String? ipoDate;
  final String? fullTimeEmployees;
  final String? range;
  final double? changes;
  final double? changesPercentage;
  final double? volAvg;
  final double? lastDiv;
  final String? currency;

  // Key Metrics (TTM or Annual)
  final double? peRatio;
  final double? pbRatio;
  final double? debtToEquity;
  final double? currentRatio;
  final double? roe;
  final double? dividendYield;
  final double? dcf; // Discounted Cash Flow

  FmpData(
      {required this.symbol,
      required this.companyName,
      required this.description,
      required this.sector,
      required this.industry,
      required this.price,
      required this.marketCap,
      required this.beta,
      required this.isEtf,
      this.website,
      this.ceo,
      this.exchange,
      this.country,
      this.image,
      this.ipoDate,
      this.fullTimeEmployees,
      this.range,
      this.changes,
      this.changesPercentage,
      this.volAvg,
      this.lastDiv,
      this.currency,
      this.peRatio,
      this.pbRatio,
      this.debtToEquity,
      this.currentRatio,
      this.roe,
      this.dividendYield,
      this.dcf});
}

// Einstellungen für die Strategie-Berechnung
class AppSettings {
  final int themeModeIndex;
  final int chartRangeDays;
  final int projectionDays;
  final bool showPatternMarkers;
  final bool showDonchian;
  final bool showSupertrend;
  final bool showBB;
  final bool showRSI;
  final bool showMACD;
  final bool showVolume;
  final bool showStochastic;
  final bool showOBV;
  final bool showEMA;
  final bool showCandles;
  final bool showTradeLines;
  final bool showAdx;
  
  // Strategie Params für manuelle Analyse
  final int entryStrategy; // 0=Market, 1=Pullback, 2=Breakout
  final double entryPadding;
  final int entryPaddingType; // 0=%, 1=ATR
  final int stopMethod; // 0=Donchian, 1=%, 2=ATR
  final double stopPercent;
  final double atrMult;
  final int tpMethod; // 0=RR, 1=%, 2=ATR
  final double rrTp1;
  final double rrTp2;
  final double tpPercent1;
  final double tpPercent2;

  final String? alphaVantageKey;
  final String? fmpKey;

  AppSettings({
    this.themeModeIndex = 1,
    this.chartRangeDays = 252,
    this.projectionDays = 15,
    this.showPatternMarkers = true,
    this.showDonchian = true,
    this.showSupertrend = true,
    this.showBB = true,
    this.showRSI = true,
    this.showMACD = false,
    this.showVolume = true,
    this.showStochastic = false,
    this.showOBV = false,
    this.showEMA = true,
    this.showCandles = false,
    this.showTradeLines = true,
    this.showAdx = false,
    this.entryStrategy = 0,
    this.entryPadding = 0.2,
    this.entryPaddingType = 0,
    this.stopMethod = 2,
    this.stopPercent = 5.0,
    this.atrMult = 2.0,
    this.tpMethod = 0,
    this.rrTp1 = 1.5,
    this.rrTp2 = 3.0,
    this.tpPercent1 = 5.0,
    this.tpPercent2 = 10.0,
    this.alphaVantageKey,
    this.fmpKey, 
  });

  AppSettings copyWith({
    int? themeModeIndex,
    int? chartRangeDays,
    int? projectionDays,
    bool? showPatternMarkers,
    bool? showDonchian,
    bool? showSupertrend,
    bool? showBB,
    bool? showRSI,
    bool? showMACD,
    bool? showVolume,
    bool? showStochastic,
    bool? showOBV,
    bool? showEMA,
    bool? showCandles,
    bool? showTradeLines,
    bool? showAdx,
    int? entryStrategy,
    double? entryPadding,
    int? entryPaddingType,
    int? stopMethod,
    double? stopPercent,
    double? atrMult,
    int? tpMethod,
    double? rrTp1,
    double? rrTp2,
    double? tpPercent1,
    double? tpPercent2,
    String? alphaVantageKey,
    String? fmpKey,
  }) {
    return AppSettings(
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      chartRangeDays: chartRangeDays ?? this.chartRangeDays,
      projectionDays: projectionDays ?? this.projectionDays,
      showPatternMarkers: showPatternMarkers ?? this.showPatternMarkers,
      showDonchian: showDonchian ?? this.showDonchian,
      showSupertrend: showSupertrend ?? this.showSupertrend,
      showBB: showBB ?? this.showBB,
      showRSI: showRSI ?? this.showRSI,
      showMACD: showMACD ?? this.showMACD,
      showVolume: showVolume ?? this.showVolume,
      showStochastic: showStochastic ?? this.showStochastic,
      showOBV: showOBV ?? this.showOBV,
      showEMA: showEMA ?? this.showEMA,
      showCandles: showCandles ?? this.showCandles,
      showTradeLines: showTradeLines ?? this.showTradeLines,
      showAdx: showAdx ?? this.showAdx,
      entryStrategy: entryStrategy ?? this.entryStrategy,
      entryPadding: entryPadding ?? this.entryPadding,
      entryPaddingType: entryPaddingType ?? this.entryPaddingType,
      stopMethod: stopMethod ?? this.stopMethod,
      stopPercent: stopPercent ?? this.stopPercent,
      atrMult: atrMult ?? this.atrMult,
      tpMethod: tpMethod ?? this.tpMethod,
      rrTp1: rrTp1 ?? this.rrTp1,
      rrTp2: rrTp2 ?? this.rrTp2,
      tpPercent1: tpPercent1 ?? this.tpPercent1,
      tpPercent2: tpPercent2 ?? this.tpPercent2,
      alphaVantageKey: alphaVantageKey ?? this.alphaVantageKey,
      fmpKey: fmpKey ?? this.fmpKey,
    );
  }
}

// Neue Klassen für Top Movers History
class TopMoverRecord {
  final String symbol;
  final int score;
  final double priceAtScan;
  final String signalType; // "Buy" or "Sell"

  TopMoverRecord({
    required this.symbol,
    required this.score,
    required this.priceAtScan,
    required this.signalType,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'score': score,
        'priceAtScan': priceAtScan,
        'signalType': signalType,
      };

  factory TopMoverRecord.fromJson(Map<String, dynamic> json) => TopMoverRecord(
        symbol: json['symbol'],
        score: json['score'],
        priceAtScan: json['priceAtScan'],
        signalType: json['signalType'],
      );
}

class TopMoverScanResult {
  final DateTime scanDate;
  final TimeFrame timeFrame;
  final List<TopMoverRecord> topMovers; // Combined list

  TopMoverScanResult({
    required this.scanDate,
    required this.timeFrame,
    required this.topMovers,
  });

  Map<String, dynamic> toJson() => {
        'scanDate': scanDate.toIso8601String(),
        'timeFrame': timeFrame.index,
        'topMovers': topMovers.map((e) => e.toJson()).toList(),
      };

  factory TopMoverScanResult.fromJson(Map<String, dynamic> json) =>
      TopMoverScanResult(
        scanDate: DateTime.parse(json['scanDate']),
        timeFrame: TimeFrame.values[json['timeFrame'] ?? 3], // Default to d1
        topMovers: List<TopMoverRecord>.from(
            (json['topMovers'] as List).map((x) => TopMoverRecord.fromJson(x))),
      );
}

class ProjectionResult {
  final List<double?> mid;
  final List<double?> upper;
  final List<double?> lower;
  ProjectionResult(this.mid, this.upper, this.lower);
}

class TradeSignal {
  final String type;
  final double entryPrice;
  final double stopLoss;
  final double takeProfit1;
  final double takeProfit2;
  final double riskRewardRatio;
  final int score;
  final List<String> reasons;
  final String chartPattern;

  // Zusatzinfos für ETA
  final double? tp1Percent;
  final double? tp2Percent;
  final Map<String, dynamic>? indicatorValues;

  TradeSignal({
    required this.type,
    required this.entryPrice,
    required this.stopLoss,
    required this.takeProfit1,
    required this.takeProfit2,
    required this.riskRewardRatio,
    required this.score,
    required this.reasons,
    required this.chartPattern,
    this.tp1Percent,
    this.tp2Percent,
    this.indicatorValues,
  });
}

class ComputedData {
  final List<PriceBar> bars;
  final List<double?> sma50;
  final List<double?> ema20;
  final List<double?> rsi;
  final List<double?> macd;
  final List<double?> macdSignal;
  final List<double?> macdHist;
  final List<double?> atr;

  // Neue Felder für Charts & Scoreboard
  final List<double?> bbUp, bbMid, bbLo;
  final List<double?> donchianUp, donchianMid, donchianLo;
  final List<double?> stLine;
  final List<bool> stBull;
  final List<bool> squeezeFlags;
  final List<double?> adx;
  final List<double?> stochK;
  final List<double?> stochD;
  final List<double?> obv;
  final ProjectionResult? proj;
  final FundamentalData? fundamentals;

  final TradeSignal? latestSignal;

  ComputedData({
    required this.bars,
    required this.sma50,
    required this.ema20,
    required this.rsi,
    required this.macd,
    required this.macdSignal,
    required this.macdHist,
    required this.atr,
    required this.bbUp,
    required this.bbMid,
    required this.bbLo,
    required this.donchianUp,
    required this.donchianMid,
    required this.donchianLo,
    required this.stLine,
    required this.stBull,
    required this.squeezeFlags,
    required this.adx,
    required this.stochK,
    required this.stochD,
    required this.obv,
    this.proj,
    this.fundamentals,
    this.latestSignal,
  });
}
