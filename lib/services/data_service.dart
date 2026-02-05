import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class DataService {
  // Cache für Yahoo Session (Cookie & Crumb)
  static String? _yahooCookie;
  static String? _yahooCrumb;

  // Holt sich erst einen Cookie von der Hauptseite und dann den Crumb von der API
  Future<void> _ensureYahooSession() async {
    if (_yahooCrumb != null) return;

    try {
      debugPrint("Initialisiere Yahoo Session (Cookie & Crumb)...");
      const userAgent =
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36";

      // 1. Cookie holen
      final r1 = await http.get(Uri.parse('https://finance.yahoo.com'),
          headers: {"User-Agent": userAgent});
      final rawCookie = r1.headers['set-cookie'];

      if (rawCookie != null) {
        _yahooCookie = rawCookie;

        // 2. Crumb holen (mit dem Cookie)
        final r2 = await http.get(
            Uri.parse('https://query1.finance.yahoo.com/v1/test/getcrumb'),
            headers: {"Cookie": _yahooCookie!, "User-Agent": userAgent});

        if (r2.statusCode == 200) {
          _yahooCrumb = r2.body.trim();
          debugPrint("Yahoo Crumb erhalten: $_yahooCrumb");
        }
      }
    } catch (e) {
      debugPrint("Yahoo Session Init Fehler: $e");
    }
  }

  Future<List<PriceBar>> fetchBars(String symbol,
      {TimeFrame interval = TimeFrame.d1}) async {
    // Stooq unterstützt nur Tagesdaten. Bei anderen Intervallen direkt zu Yahoo.
    if (interval == TimeFrame.d1) {
      // 1. Versuch: Stooq (CSV) für Tagesdaten
      try {
        final bars = await _fetchBarsStooq(symbol);
        if (bars.isNotEmpty) return bars;
      } catch (e) {
        debugPrint("Stooq Fehler (evtl. Limit): $e");
      }
    }

    // 2. Versuch: Yahoo Finance (JSON) als Fallback
    debugPrint(
        "Versuche Yahoo Finance für Chart-Daten (Intervall: ${interval.name})...");
    try {
      final bars = await _fetchBarsYahoo(symbol, interval: interval);
      return bars;
    } catch (e) {
      debugPrint("Yahoo Chart Fehler: $e");
      throw Exception(
          "Keine Daten für ${interval.name} verfügbar (Stooq/Yahoo Fehler).");
    }
  }

  Future<List<PriceBar>> _fetchBarsStooq(String symbol) async {
    final cleanSym = symbol.trim().toLowerCase();
    final url = Uri.parse('https://stooq.com/q/d/l/?s=$cleanSym&i=d');

    debugPrint("--- Stooq Fetch Start: $cleanSym ---");
    debugPrint("URL: $url");

    try {
      final resp = await http.get(url);
      debugPrint("Stooq HTTP Status: ${resp.statusCode}");
      if (resp.statusCode != 200)
        throw Exception("Fehler beim Laden (HTTP ${resp.statusCode})");

      final content = utf8.decode(resp.bodyBytes);
      // Preview loggen, um zu sehen ob HTML oder "No data" kommt
      debugPrint(
          "Stooq Response Preview: ${content.substring(0, math.min(content.length, 200)).replaceAll("\n", " ")}");

      // Check auf Limit-Nachricht oder HTML
      if (content.contains("limit exceeded") ||
          content.trim().startsWith("<")) {
        throw Exception("Stooq Daily Limit erreicht oder ungültige Antwort.");
      }

      final lines = const LineSplitter().convert(content);
      if (lines.length < 2) {
        debugPrint("Stooq: Zu wenige Zeilen (${lines.length}).");
        return [];
      }

      final bars = <PriceBar>[];
      int parseErrors = 0;
      // Skip Header
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');
        if (parts.length < 5) {
          parseErrors++;
          continue;
        }
        try {
          // Stooq Format: Date, Open, High, Low, Close
          final dt = DateTime.parse(parts[0]);
          final o = double.parse(parts[1]);
          final h = double.parse(parts[2]);
          final l = double.parse(parts[3]);
          final c = double.parse(parts[4]);
          final v = parts.length > 5 ? (int.tryParse(parts[5]) ?? 0) : 0;

          bars.add(PriceBar(
              date: dt, open: o, high: h, low: l, close: c, volume: v));
        } catch (e) {
          parseErrors++;
        }
      }

      debugPrint(
          "Stooq: ${bars.length} Bars erfolgreich geparst. (Fehlerhafte Zeilen: $parseErrors)");

      // Sortieren nach Datum aufsteigend
      bars.sort((a, b) => a.date.compareTo(b.date));
      return bars;
    } catch (e) {
      debugPrint("Stooq Exception: $e");
      throw e; // Weiterwerfen für Fallback
    }
  }

  Future<List<PriceBar>> _fetchBarsYahoo(String symbol,
      {TimeFrame interval = TimeFrame.d1}) async {
    await _ensureYahooSession();

    // Symbol Konvertierung (ähnlich wie bei Fundamentals)
    String ySymbol = symbol.trim().toUpperCase();
    if (ySymbol.endsWith(".US")) ySymbol = ySymbol.replaceAll(".US", "");

    if (!ySymbol.contains(".") && !ySymbol.contains("-")) {
      if (ySymbol.length > 3 &&
          (ySymbol.endsWith("USD") || ySymbol.endsWith("EUR"))) {
        int splitIdx = ySymbol.length - 3;
        ySymbol =
            "${ySymbol.substring(0, splitIdx)}-${ySymbol.substring(splitIdx)}";
      }
    }

    // Range dynamisch anpassen basierend auf dem Intervall, wie von Yahoo gefordert
    String range;
    if (interval.apiString.contains('m')) {
      range = '60d'; // Minuten-Daten: max 60 Tage
    } else if (interval.apiString == '60m') { // '1h'
      range = '730d'; // Stunden-Daten: max 2 Jahre
    } else {
      range = '10y'; // Tages/Wochen-Daten: max 10 Jahre
    }

    final apiInterval = interval.apiString;
    String urlStr =
        'https://query2.finance.yahoo.com/v8/finance/chart/$ySymbol?interval=$apiInterval&range=$range';
    if (_yahooCrumb != null) urlStr += '&crumb=$_yahooCrumb';

    final url = Uri.parse(urlStr);
    final headers = {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
    };
    if (_yahooCookie != null) headers["Cookie"] = _yahooCookie!;

    debugPrint("Yahoo Chart URL: $url");
    final resp = await http.get(url, headers: headers);

    if (resp.statusCode != 200) {
      throw Exception("Yahoo API Status: ${resp.statusCode}");
    }

    final json = jsonDecode(resp.body);
    final result = json['chart']['result'];
    if (result == null || (result as List).isEmpty)
      throw Exception("Yahoo: Leeres Result");

    final data = result[0];
    final timestamps = List<int>.from(data['timestamp'] ?? []);
    final quote = data['indicators']['quote'][0];
    final closes = List<num?>.from(quote['close'] ?? []);
    final opens = List<num?>.from(quote['open'] ?? []);
    final highs = List<num?>.from(quote['high'] ?? []);
    final lows = List<num?>.from(quote['low'] ?? []);
    final volumes = List<num?>.from(quote['volume'] ?? []);

    final bars = <PriceBar>[];
    for (int i = 0; i < timestamps.length; i++) {
      if (closes[i] == null) continue; // Skip incomplete bars
      final dt = DateTime.fromMillisecondsSinceEpoch(timestamps[i] * 1000);
      bars.add(PriceBar(
        date: dt,
        open: (opens[i] ?? closes[i])!.toDouble(),
        high: (highs[i] ?? closes[i])!.toDouble(),
        low: (lows[i] ?? closes[i])!.toDouble(),
        close: closes[i]!.toDouble(),
        volume: (volumes[i] ?? 0).toInt(),
      ));
    }
    debugPrint("Yahoo: ${bars.length} Bars geladen.");
    return bars;
  }

  String _normalizeSymbolForYahoo(String symbol) {
    String ySymbol = symbol.trim().toUpperCase();
    if (ySymbol.endsWith(".US")) {
      ySymbol = ySymbol.replaceAll(".US", "");
    }

    if (!ySymbol.contains(".") && !ySymbol.contains("-")) {
      if (ySymbol.length > 3 &&
          (ySymbol.endsWith("USD") || ySymbol.endsWith("EUR"))) {
        int splitIdx = ySymbol.length - 3;
        ySymbol =
            "${ySymbol.substring(0, splitIdx)}-${ySymbol.substring(splitIdx)}";
      }
    }
    return ySymbol;
  }

  Future<FundamentalData?> fetchFundamentals(String symbol) async {
    // Mapping Stooq -> Yahoo
    // Stooq: AAPL.US -> Yahoo: AAPL
    // Stooq: BMW.DE -> Yahoo: BMW.DE
    // Stooq: BTCUSD -> Yahoo: BTC-USD

    String ySymbol = _normalizeSymbolForYahoo(symbol);

    debugPrint("Lade Fundamentals von Yahoo für: $ySymbol");

    // Session sicherstellen (Cookie/Crumb)
    await _ensureYahooSession();

    // URL bauen (Crumb anhängen falls vorhanden)
    String urlStr =
        'https://query2.finance.yahoo.com/v10/finance/quoteSummary/$ySymbol?modules=summaryDetail,financialData,defaultKeyStatistics,assetProfile';
    if (_yahooCrumb != null) {
      urlStr += '&crumb=$_yahooCrumb';
    }
    final url = Uri.parse(urlStr);

    // WICHTIG: User-Agent setzen, sonst blockiert Yahoo oft die Anfrage
    final headers = {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
      "Accept": "*/*",
      "Origin": "https://finance.yahoo.com",
      "Referer": "https://finance.yahoo.com/quote/$ySymbol",
    };

    if (_yahooCookie != null) {
      headers["Cookie"] = _yahooCookie!;
    }

    try {
      final resp = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      debugPrint("Yahoo Primary API Status: ${resp.statusCode} für $ySymbol");

      // Fallback: Wenn 401/403 (Unauthorized), versuche die einfachere Quote-API
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        debugPrint(
            "Yahoo Primary API Auth Error. Body: ${resp.body.substring(0, math.min(resp.body.length, 150))}");
        return await _fetchFundamentalsFallback(ySymbol, headers);
      }

      if (resp.statusCode != 200) {
        debugPrint("Yahoo Error Code: ${resp.statusCode} für $ySymbol");
        debugPrint(
            "Body: ${resp.body.substring(0, math.min(resp.body.length, 200))}...");
        return null;
      }

      final json = jsonDecode(resp.body);
      final result = json['quoteSummary']['result'];
      if (result == null || (result as List).isEmpty) {
        debugPrint("Yahoo: Keine Daten im Result für $ySymbol");
        return null;
      }

      final data = result[0];
      final summary = data['summaryDetail'] ?? {};
      final stats = data['defaultKeyStatistics'] ?? {};
      final profile = data['assetProfile'] ?? {};
      final financial = data['financialData'] ?? {};

      // Hilfsfunktion robuster machen (manchmal fehlt 'raw')
      double? getRaw(Map m, String k) {
        final val = m[k];
        if (val == null) return null;
        if (val is num) return val.toDouble();
        if (val is Map && val['raw'] is num)
          return (val['raw'] as num).toDouble();
        return null;
      }

      String? getStr(Map m, String k) => m[k] is String ? m[k] : null;

      final fd = FundamentalData(
        sector: getStr(profile, 'sector'),
        industry: getStr(profile, 'industry'),
        peRatio: getRaw(summary, 'trailingPE'),
        forwardPe: getRaw(summary, 'forwardPE'),
        pbRatio: getRaw(stats, 'priceToBook'),
        dividendYield: getRaw(summary, 'dividendYield'),
        marketCap: getRaw(summary, 'marketCap'),
        currency: getStr(financial, 'financialCurrency'),
      );

      debugPrint(
          "Fundamentals erfolgreich geladen für $ySymbol. KGV: ${fd.peRatio}");
      return fd;
    } catch (e) {
      // Fehler beim Abruf oder Parsen ignorieren wir hier stillschweigend,
      // da es Zusatzdaten sind.
      debugPrint("Fehler bei Fundamentals: $e");
      return null;
    }
  }

  // Fallback-Methode für einfachere Daten (ohne Sektor/Industrie, aber mit KGV/Marktkap)
  Future<FundamentalData?> _fetchFundamentalsFallback(
      String symbol, Map<String, String> headers) async {
    debugPrint("Versuche Fallback-API für $symbol");

    String urlStr =
        'https://query2.finance.yahoo.com/v7/finance/quote?symbols=$symbol';
    if (_yahooCrumb != null) {
      urlStr += '&crumb=$_yahooCrumb';
    }
    final url = Uri.parse(urlStr);

    try {
      final resp = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      debugPrint("Fallback API Status: ${resp.statusCode} für $symbol");

      if (resp.statusCode != 200) {
        debugPrint("Fallback API Error Body: ${resp.body}");
        return null;
      }

      final json = jsonDecode(resp.body);
      final result = json['quoteResponse']['result'];
      if (result == null || (result as List).isEmpty) {
        debugPrint(
            "Fallback: Keine Daten in quoteResponse['result'] für $symbol");
        return null;
      }

      final data = result[0];
      debugPrint("Fallback: Daten erfolgreich geladen für $symbol");

      return FundamentalData(
        sector: null, // Nicht verfügbar in dieser API
        industry: null,
        peRatio: data['trailingPE']?.toDouble(),
        forwardPe: data['forwardPE']?.toDouble(),
        pbRatio: data['priceToBook']?.toDouble(),
        dividendYield: data['dividendYield']?.toDouble() != null
            ? (data['dividendYield'] / 100.0)
            : null,
        marketCap: data['marketCap']?.toDouble(),
        currency: data['currency'],
      );
    } catch (e, stack) {
      debugPrint("Fallback Fehler: $e\n$stack");
      return null;
    }
  }

  Future<double?> fetchRegularMarketPrice(String symbol) async {
    // Symbol mapping logic from fetchFundamentals
    String ySymbol = _normalizeSymbolForYahoo(symbol);

    debugPrint("Lade Live-Preis von Yahoo für: $ySymbol");

    await _ensureYahooSession();

    String urlStr =
        'https://query2.finance.yahoo.com/v7/finance/quote?symbols=$ySymbol';
    if (_yahooCrumb != null) {
      urlStr += '&crumb=$_yahooCrumb';
    }
    final url = Uri.parse(urlStr);

    final headers = {
      "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
    };
    if (_yahooCookie != null) {
      headers["Cookie"] = _yahooCookie!;
    }

    try {
      final resp = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        debugPrint("Live Preis API Error: ${resp.statusCode} für $ySymbol");
        return null;
      }

      final json = jsonDecode(resp.body);
      final result = json['quoteResponse']['result'];
      if (result == null || (result as List).isEmpty) {
        debugPrint("Live Preis: Keine Daten für $ySymbol");
        return null;
      }

      final data = result[0];
      final price = data['regularMarketPrice'];
      final marketState = data['marketState'];

      // Nur Preise von regulären Handelssessions verwenden, um Pre/Post-Market Sprünge zu ignorieren
      if (price is num &&
          (marketState == "REGULAR" ||
              marketState == "PRE" ||
              marketState == "POST")) {
        debugPrint("Live Preis für $ySymbol: $price (Status: $marketState)");
        return price.toDouble();
      }
      debugPrint(
          "Live Preis für $ySymbol nicht im REGULAR-Markt gefunden (Status: $marketState)");
      return null;
    } catch (e) {
      debugPrint("Live Preis Fehler: $e");
      return null;
    }
  }

  // --- Financial Modeling Prep API ---
  Future<FmpData?> fetchFmpData(String symbol, String apiKey) async {
    // FMP nutzt oft "BTCUSD" statt "BTC-USD"
    String fmpSymbol = symbol.toUpperCase();
    if (fmpSymbol.contains("-") &&
        (fmpSymbol.endsWith("USD") || fmpSymbol.endsWith("EUR"))) {
      fmpSymbol = fmpSymbol.replaceAll("-", "");
    }
    if (fmpSymbol.endsWith(".DEF")) {
      fmpSymbol = fmpSymbol.replaceAll(".DEF", ".DE");
    }

    debugPrint("--- FMP Fetch Start: $fmpSymbol ---");

    // Default Werte
    String companyName = fmpSymbol;
    String description = "Keine Beschreibung verfügbar (Legacy API Limit).";
    String sector = "N/A";
    String industry = "N/A";
    double price = 0.0;
    double marketCap = 0.0;
    double beta = 0.0;
    bool isEtf = false;

    String? website;
    String? ceo;
    String? exchange;
    String? country;
    String? image;
    String? ipoDate;
    String? fullTimeEmployees;
    String? range;
    double? changes;
    double? changesPercentage;
    double? volAvg;
    double? lastDiv;
    String? currency;

    double? dcf;

    double? peRatio;
    double? pbRatio;
    double? debtToEquity;
    double? currentRatio;
    double? roe;
    double? dividendYield;

    try {
      // 1. Versuch: Profile (Stable Endpoint - bevorzugt)
      bool profileLoaded = false;
      // Nutzung von stable/profile wie gewünscht
      final urlProfile = Uri.parse(
          'https://financialmodelingprep.com/stable/profile?symbol=$fmpSymbol&apikey=$apiKey');

      try {
        final respProfile =
            await http.get(urlProfile).timeout(const Duration(seconds: 5));
        if (respProfile.statusCode == 200) {
          final List jsonProfile = jsonDecode(respProfile.body);
          if (jsonProfile.isNotEmpty) {
            final p = jsonProfile[0];
            companyName = p['companyName'] ?? companyName;
            description = p['description'] ?? description;
            sector = p['sector'] ?? sector;
            industry = p['industry'] ?? industry;
            price = (p['price'] as num?)?.toDouble() ?? price;
            marketCap = (p['mktCap'] as num?)?.toDouble() ?? marketCap;
            beta = (p['beta'] as num?)?.toDouble() ?? beta;
            isEtf = p['isEtf'] ?? false;
            dcf = (p['dcf'] as num?)?.toDouble();

            // Neue Felder mappen
            website = p['website'];
            ceo = p['ceo'];
            exchange = p['exchangeShortName'] ?? p['exchange'];
            country = p['country'];
            image = p['image'];
            ipoDate = p['ipoDate'];
            fullTimeEmployees = p['fullTimeEmployees'];
            range = p['range'];
            changes = (p['change'] as num?)?.toDouble();
            changesPercentage = (p['changePercentage'] as num?)?.toDouble();
            volAvg = (p['averageVolume'] as num?)?.toDouble();
            lastDiv = (p['lastDividend'] as num?)?.toDouble();
            currency = p['currency'];

            profileLoaded = true;
            debugPrint("FMP Profile erfolgreich geladen.");
          }
        } else {
          debugPrint(
              "FMP Profile Status: ${respProfile.statusCode} (Nutze Fallback)");
        }
      } catch (e) {
        debugPrint("FMP Profile Fehler: $e");
      }

      // 2. Quote (Immer versuchen für aktuelle Preise & PE, falls Profile/Ratios fehlen)
      // Quote ist oft im Free Plan enthalten und hat PE.
      final urlQuote = Uri.parse(
          'https://financialmodelingprep.com/api/v3/quote/$fmpSymbol?apikey=$apiKey');
      try {
        final respQuote =
            await http.get(urlQuote).timeout(const Duration(seconds: 5));
        if (respQuote.statusCode == 200) {
          final List jsonQuote = jsonDecode(respQuote.body);
          if (jsonQuote.isNotEmpty) {
            final q = jsonQuote[0];
            if (companyName == fmpSymbol)
              companyName = q['name'] ?? companyName;
            price = (q['price'] as num?)?.toDouble() ?? price;
            if (marketCap == 0.0)
              marketCap = (q['marketCap'] as num?)?.toDouble() ?? marketCap;

            // PE aus Quote holen, falls noch null (wichtig bei 402 Error auf Ratios)
            if (peRatio == null) peRatio = (q['pe'] as num?)?.toDouble();
            if (currency == null) currency = q['currency'];

            debugPrint("FMP Quote geladen (Preis: $price, PE: $peRatio)");
          }
        }
      } catch (e) {
        debugPrint("FMP Quote Fehler: $e");
      }

      // 3. Key Metrics (User URL: /stable/key-metrics)
      // Hier holen wir die detaillierten Kennzahlen
      final urlMetrics = Uri.parse(
          'https://financialmodelingprep.com/stable/key-metrics?symbol=$fmpSymbol&apikey=$apiKey');
      debugPrint("FMP Metrics URL: $urlMetrics");

      try {
        final respMetrics =
            await http.get(urlMetrics).timeout(const Duration(seconds: 10));
        if (respMetrics.statusCode == 200) {
          final List jsonMetrics = jsonDecode(respMetrics.body);
          if (jsonMetrics.isNotEmpty) {
            final m = jsonMetrics[0];

            currentRatio = (m['currentRatio'] as num?)?.toDouble();
            roe = (m['returnOnEquity'] as num?)?.toDouble();

            // PE aus EarningsYield berechnen (PE = 1 / Yield), falls noch nicht da
            if (peRatio == null) {
              double? ey = (m['earningsYield'] as num?)?.toDouble();
              if (ey != null && ey != 0) {
                peRatio = 1.0 / ey;
              }
            }

            // Debt/Equity ist oft nicht direkt drin, wir schauen mal
            debtToEquity = (m['debtToEquity'] as num?)?.toDouble();
            // Fallback: NetDebtToEBITDA als Indikator nutzen? Lieber nicht mischen.

            dividendYield = (m['dividendYield'] as num?)?.toDouble();

            debugPrint("FMP Metrics geladen.");
          }
        } else {
          debugPrint("FMP Metrics Status: ${respMetrics.statusCode}");
        }
      } catch (e) {
        debugPrint("FMP Metrics Fehler: $e");
      }

      // 4. Ratios (User URL: /stable/ratios)
      // Ergänzung für PE, PB, DebtToEquity etc.
      final urlRatios = Uri.parse(
          'https://financialmodelingprep.com/stable/ratios?symbol=$fmpSymbol&apikey=$apiKey');
      debugPrint("FMP Ratios URL: $urlRatios");

      try {
        final respRatios =
            await http.get(urlRatios).timeout(const Duration(seconds: 10));
        if (respRatios.statusCode == 200) {
          final List jsonRatios = jsonDecode(respRatios.body);
          if (jsonRatios.isNotEmpty) {
            final r = jsonRatios[0];

            // Wir bevorzugen die expliziten Ratios, falls vorhanden
            if (r['priceToEarningsRatio'] != null)
              peRatio = (r['priceToEarningsRatio'] as num).toDouble();
            if (r['priceToBookRatio'] != null)
              pbRatio = (r['priceToBookRatio'] as num).toDouble();
            if (r['debtToEquityRatio'] != null)
              debtToEquity = (r['debtToEquityRatio'] as num).toDouble();
            if (r['currentRatio'] != null)
              currentRatio = (r['currentRatio'] as num).toDouble();
            if (r['dividendYield'] != null)
              dividendYield = (r['dividendYield'] as num).toDouble();

            debugPrint("FMP Ratios geladen.");
          }
        } else {
          debugPrint("FMP Ratios Status: ${respRatios.statusCode}");
        }
      } catch (e) {
        debugPrint("FMP Ratios Fehler: $e");
      }

      // Mapping
      return FmpData(
        symbol: fmpSymbol,
        companyName: companyName,
        description: description,
        sector: sector,
        industry: industry,
        price: price,
        marketCap: marketCap,
        beta: beta,
        isEtf: isEtf,
        website: website,
        ceo: ceo,
        exchange: exchange,
        country: country,
        image: image,
        ipoDate: ipoDate,
        fullTimeEmployees: fullTimeEmployees,
        range: range,
        changes: changes,
        changesPercentage: changesPercentage,
        volAvg: volAvg,
        lastDiv: lastDiv,
        currency: currency,

        // Metrics
        peRatio: peRatio,
        pbRatio: pbRatio,
        debtToEquity: debtToEquity,
        currentRatio: currentRatio,
        roe: roe,
        dividendYield: dividendYield,
        dcf: dcf,
      );
    } catch (e, stack) {
      debugPrint("FMP Exception: $e\n$stack");
      return null;
    }
  }

  // --- News API (Yahoo RSS - Kostenlos) ---
  Future<List<NewsItem>> fetchNews(String symbol) async {
    // Symbol bereinigen (Yahoo Ticker Format)
    String ySymbol = symbol.toUpperCase();
    if (ySymbol.endsWith(".US")) ySymbol = ySymbol.replaceAll(".US", "");

    final url = Uri.parse(
        "https://feeds.finance.yahoo.com/rss/2.0/headline?s=$ySymbol&region=US&lang=en-US");
    debugPrint("Lade News von: $url");

    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final xml = utf8.decode(resp.bodyBytes);
        // Simples Regex Parsing für RSS Items (um XML Package Dependency zu sparen)
        final items = <NewsItem>[];
        final regex = RegExp(
            r'<item>.*?<title>(.*?)</title>.*?<link>(.*?)</link>.*?<pubDate>(.*?)</pubDate>.*?</item>',
            dotAll: true);

        for (final match in regex.allMatches(xml)) {
          final title = match
                  .group(1)
                  ?.replaceAll("<![CDATA[", "")
                  .replaceAll("]]>", "")
                  .trim() ??
              "";
          final link = match.group(2)?.trim() ?? "";
          final pubDate = match.group(3)?.trim() ?? "";
          if (title.isNotEmpty)
            items.add(NewsItem(title: title, link: link, pubDate: pubDate));
        }
        return items;
      }
    } catch (e) {
      debugPrint("News Fehler: $e");
    }
    return [];
  }
}
