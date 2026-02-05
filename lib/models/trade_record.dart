import 'dart:convert';
import '../models/models.dart';

enum TradeStatus { pending, open, closed, stoppedOut, takeProfit }

class TradeRecord {
  final String id;
  final String symbol;
  final DateTime entryDate;
  double entryPrice;
  double quantity; // Anzahl Aktien (fiktiv)

  double stopLoss;
  final double takeProfit1;
  final double takeProfit2;

  TradeStatus status;
  DateTime? exitDate;
  double? exitPrice;
  bool tp1Hit;
  double realizedPnL; // Gewinn/Verlust in Währung
  double? lastPrice; // Letzter bekannter Kurs für Anzeige

  // Snapshot der Analyse zum Zeitpunkt des Kaufs
  final int entryScore;
  final String entryReasons; // Kommagetrennte Gründe
  final String entryPattern;
  final Map<String, dynamic> aiAnalysisSnapshot;
  final TimeFrame? botTimeFrame;

  // Historie & Ausführung
  final DateTime? entryExecutionDate;
  final DateTime? closeExecutionDate;
  final DateTime? lastScanDate;
  final double? executionPrice;

  TradeRecord({
    required this.id,
    required this.symbol,
    required this.entryDate,
    required this.entryPrice,
    required this.quantity,
    required this.stopLoss,
    required this.takeProfit1,
    required this.takeProfit2,
    this.status =
        TradeStatus.pending, // Standardmäßig erst pending (Warten auf Limit)
    this.exitDate,
    this.tp1Hit = false,
    this.exitPrice,
    this.realizedPnL = 0.0,
    this.lastPrice,
    this.entryScore = 0,
    this.entryReasons = "",
    this.entryPattern = "",
    this.aiAnalysisSnapshot = const {},
    this.botTimeFrame,
    this.entryExecutionDate,
    this.closeExecutionDate,
    this.lastScanDate,
    this.executionPrice,
  });

  // Berechnet den aktuellen unrealisierten Gewinn/Verlust (Long & Short)
  double calcUnrealizedPnL(double currentPrice) {
    if (status != TradeStatus.open) return 0.0;
    // Nutze echten Ausführungspreis falls vorhanden, sonst Entry
    double basePrice = executionPrice ?? entryPrice;
    bool isLong = takeProfit1 > entryPrice;
    return isLong
        ? (currentPrice - basePrice) * quantity
        : (basePrice - currentPrice) * quantity;
  }

  // Berechnet den aktuellen unrealisierten Gewinn in Prozent
  double calcUnrealizedPercent(double currentPrice) {
    if (status != TradeStatus.open) return 0.0;
    double basePrice = executionPrice ?? entryPrice;
    if (basePrice == 0) return 0.0;

    bool isLong = takeProfit1 > entryPrice;
    return isLong
        ? ((currentPrice - basePrice) / basePrice) * 100
        : ((basePrice - currentPrice) / basePrice) * 100;
  }

  TradeRecord copyWith({
    String? id,
    String? symbol,
    DateTime? entryDate,
    double? entryPrice,
    double? quantity,
    double? stopLoss,
    double? takeProfit1,
    double? takeProfit2,
    TradeStatus? status,
    DateTime? exitDate,
    double? exitPrice,
    bool? tp1Hit,
    double? realizedPnL,
    double? lastPrice,
    int? entryScore,
    String? entryReasons,
    String? entryPattern,
    Map<String, dynamic>? aiAnalysisSnapshot,
    TimeFrame? botTimeFrame,
    DateTime? entryExecutionDate,
    DateTime? closeExecutionDate,
    DateTime? lastScanDate,
    double? executionPrice,
  }) {
    return TradeRecord(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      entryDate: entryDate ?? this.entryDate,
      entryPrice: entryPrice ?? this.entryPrice,
      quantity: quantity ?? this.quantity,
      stopLoss: stopLoss ?? this.stopLoss,
      takeProfit1: takeProfit1 ?? this.takeProfit1,
      takeProfit2: takeProfit2 ?? this.takeProfit2,
      status: status ?? this.status,
      exitDate: exitDate ?? this.exitDate,
      exitPrice: exitPrice ?? this.exitPrice,
      tp1Hit: tp1Hit ?? this.tp1Hit,
      realizedPnL: realizedPnL ?? this.realizedPnL,
      lastPrice: lastPrice ?? this.lastPrice,
      entryScore: entryScore ?? this.entryScore,
      entryReasons: entryReasons ?? this.entryReasons,
      entryPattern: entryPattern ?? this.entryPattern,
      aiAnalysisSnapshot: aiAnalysisSnapshot ?? this.aiAnalysisSnapshot,
      botTimeFrame: botTimeFrame ?? this.botTimeFrame,
      entryExecutionDate: entryExecutionDate ?? this.entryExecutionDate,
      closeExecutionDate: closeExecutionDate ?? this.closeExecutionDate,
      lastScanDate: lastScanDate ?? this.lastScanDate,
      executionPrice: executionPrice ?? this.executionPrice,
    );
  }

  // Serialisierung für Speicherung (JSON)
  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'entryDate': entryDate.toIso8601String(),
        'entryPrice': entryPrice,
        'quantity': quantity,
        'stopLoss': stopLoss,
        'takeProfit1': takeProfit1,
        'takeProfit2': takeProfit2,
        'status': status.index,
        'exitDate': exitDate?.toIso8601String(),
        'tp1Hit': tp1Hit,
        'exitPrice': exitPrice,
        'realizedPnL': realizedPnL,
        'lastPrice': lastPrice,
        'entryScore': entryScore,
        'entryReasons': entryReasons,
        'entryPattern': entryPattern,
        'aiAnalysisSnapshot': aiAnalysisSnapshot,
        'botTimeFrame': botTimeFrame?.index,
        'entryExecutionDate': entryExecutionDate?.toIso8601String(),
        'closeExecutionDate': closeExecutionDate?.toIso8601String(),
        'lastScanDate': lastScanDate?.toIso8601String(),
        'executionPrice': executionPrice,
      };

  factory TradeRecord.fromJson(Map<String, dynamic> json) {
    return TradeRecord(
      id: json['id'],
      symbol: json['symbol'],
      entryDate: DateTime.parse(json['entryDate']),
      entryPrice: json['entryPrice'],
      quantity: json['quantity'],
      stopLoss: json['stopLoss'],
      takeProfit1: json['takeProfit1'],
      takeProfit2: json['takeProfit2'],
      status: TradeStatus.values[json['status']],
      exitDate:
          json['exitDate'] != null ? DateTime.parse(json['exitDate']) : null,
      tp1Hit: json['tp1Hit'] ?? false,
      exitPrice: json['exitPrice'],
      realizedPnL: json['realizedPnL'] ?? 0.0,
      lastPrice: json['lastPrice'],
      entryScore: json['entryScore'] ?? 0,
      entryReasons: json['entryReasons'] ?? "",
      entryPattern: json['entryPattern'] ?? "",
      aiAnalysisSnapshot: json['aiAnalysisSnapshot'] ?? {},
      botTimeFrame: json['botTimeFrame'] != null
          ? TimeFrame.values[json['botTimeFrame']]
          : null,
      entryExecutionDate: json['entryExecutionDate'] != null
          ? DateTime.parse(json['entryExecutionDate'])
          : null,
      closeExecutionDate: json['closeExecutionDate'] != null
          ? DateTime.parse(json['closeExecutionDate'])
          : null,
      lastScanDate: json['lastScanDate'] != null
          ? DateTime.parse(json['lastScanDate'])
          : null,
      executionPrice: (json['executionPrice'] as num?)?.toDouble(),
    );
  }
}
