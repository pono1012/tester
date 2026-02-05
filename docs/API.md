# 🛠 TechAna Developer API & Architecture

Diese Dokumentation richtet sich an Entwickler, die TechAna erweitern oder verstehen möchten.

---

## 🏗 Architektur

TechAna basiert auf **Flutter** und nutzt eine Service-orientierte Architektur:

### Kern-Services (`lib/services/`)
* **`DataService`**: Handhabt alle externen API-Abrufe (Aktienkurse, Krypto-Daten).
* **`PortfolioService`**: Verwaltet lokale Benutzerdaten, Transaktionen und Balances.
* **`TaIndicators`**: Eine reine Dart-Implementierung gängiger technischer Indikatoren.
* **`UpdateService`**: Prüft auf App-Updates via GitHub Releases / Shorebird.

### Datenmodelle (`lib/models/`)
* **`TradeRecord`**: Speichert einzelne Trades (Buy/Sell, Preis, Timestamp).
* **`Models`**: Enthält Definitionen für `Asset`, `Candle`, `IndicatorResult`.

---

## 🔌 Integration neuer Indikatoren

Um einen neuen Indikator hinzuzufügen:

1. Öffne `lib/services/ta_indicators.dart`.
2. Erstelle eine neue statische Methode, z.B. `calculateMyIndicator(List<double> prices)`.
3. Registriere den Indikator im `AnalysisStatsScreen` (`lib/ui/analysis_stats_screen.dart`), damit er in der UI erscheint.

```dart
// Beispiel-Struktur
static List<double> calculateSMA(List<double> data, int period) {
  // Implementierung...
}