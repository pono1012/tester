import 'package:flutter/material.dart';

class PatternDetailsScreen extends StatelessWidget {
  final String patternName;

  const PatternDetailsScreen({super.key, required this.patternName});

  @override
  Widget build(BuildContext context) {
    final info = _getPatternInfo(patternName);
    final isBullish = info['type'] == 'Bullish';
    final color = isBullish
        ? Colors.green
        : (info['type'] == 'Bearish' ? Colors.red : Colors.grey);

    return Scaffold(
      appBar: AppBar(title: Text(patternName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- Bildchen (Schematisch) ---
            Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(75),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5)
                ],
              ),
              child: CustomPaint(
                painter: PatternPainter(patternName, color),
              ),
            ),
            const SizedBox(height: 32),

            // --- Titel & Typ ---
            Text(patternName,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16)),
              child: Text(info['type']!,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 32),

            // --- Beschreibung ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Erklärung",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(info['desc']!,
                      style: const TextStyle(fontSize: 16, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _getPatternInfo(String name) {
    if (name.contains("Hammer")) {
      return {
        'type': 'Bullish',
        'desc':
            'Ein Hammer tritt nach einem Abwärtstrend auf. Er hat einen kleinen Körper am oberen Ende und einen langen unteren Schatten (Lunte). Dies zeigt, dass Verkäufer den Preis drückten, aber Käufer ihn wieder hochkauften. Ein Zeichen für eine mögliche Bodenbildung.'
      };
    }
    if (name.contains("Shooting") || name.contains("Star")) {
      return {
        'type': 'Bearish',
        'desc':
            'Der Shooting Star ist das Gegenteil des Hammers und tritt nach einem Aufwärtstrend auf. Er hat einen langen oberen Schatten und einen kleinen Körper unten. Dies signalisiert, dass Käufer scheiterten, den Preis oben zu halten.'
      };
    }
    if (name.contains("Engulfing")) {
      bool bull = name.contains("Bullish");
      return {
        'type': bull ? 'Bullish' : 'Bearish',
        'desc': bull
            ? 'Eine grüne Kerze umschließt die vorherige rote Kerze komplett. Dies zeigt massive Kaufkraftübernahme.'
            : 'Eine rote Kerze umschließt die vorherige grüne Kerze komplett. Dies zeigt massive Verkaufskraftübernahme.'
      };
    }
    if (name.contains("Doji")) {
      return {
        'type': 'Neutral',
        'desc':
            'Ein Doji hat fast den gleichen Eröffnungs- und Schlusskurs. Es sieht aus wie ein Kreuz. Es signalisiert Unentschlossenheit im Markt. Oft ein Vorbote für eine Trendumkehr.'
      };
    }
    if (name.contains("Soldiers")) {
      return {
        'type': 'Bullish',
        'desc':
            'Drei aufeinanderfolgende grüne Kerzen mit höheren Hochs und höheren Schlusskursen. Ein sehr starkes Signal für einen anhaltenden Aufwärtstrend.'
      };
    }
    if (name.contains("Double Top")) {
      return {
        'type': 'Bearish',
        'desc':
            'Der Preis erreicht zweimal ein Hoch, schafft es aber nicht, dieses zu durchbrechen. Das "M"-Muster deutet auf Widerstand und eine mögliche Trendwende nach unten hin.'
      };
    }
    return {
      'type': 'Neutral',
      'desc':
          'Kein spezifisches Muster erkannt oder das Muster ist weniger signifikant. Achte auf andere Indikatoren.'
    };
  }
}

class PatternPainter extends CustomPainter {
  final String pattern;
  final Color color;
  PatternPainter(this.pattern, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Zeichne eine schematische Kerze basierend auf dem Namen
    if (pattern.contains("Hammer")) {
      // Langer unterer Schatten, kleiner Körper oben
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, h * 0.3), width: w * 0.3, height: h * 0.2),
          paint); // Body
      canvas.drawLine(Offset(cx, h * 0.4), Offset(cx, h * 0.9),
          paint..strokeWidth = 4); // Wick
    } else if (pattern.contains("Shooting")) {
      // Langer oberer Schatten, kleiner Körper unten
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, h * 0.7), width: w * 0.3, height: h * 0.2),
          paint); // Body
      canvas.drawLine(Offset(cx, h * 0.6), Offset(cx, h * 0.1),
          paint..strokeWidth = 4); // Wick
    } else if (pattern.contains("Doji")) {
      // Kreuz
      canvas.drawLine(Offset(cx, h * 0.2), Offset(cx, h * 0.8),
          paint..strokeWidth = 4); // Vertikal
      canvas.drawLine(Offset(cx - w * 0.2, h * 0.5),
          Offset(cx + w * 0.2, h * 0.5), paint..strokeWidth = 6); // Horizontal
    } else {
      // Standard Kerze
      canvas.drawRect(
          Rect.fromCenter(
              center: Offset(cx, h * 0.5), width: w * 0.3, height: h * 0.4),
          paint);
      canvas.drawLine(
          Offset(cx, h * 0.2), Offset(cx, h * 0.8), paint..strokeWidth = 4);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
