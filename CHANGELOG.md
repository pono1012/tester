### 2026-02-07 - Update

#### Wichtige Neuerungen im Release-Management-Prozess

Wir freuen uns, Ihnen wichtige Verbesserungen in unserem internen Release-Management-Workflow vorstellen zu können. Diese Änderungen optimieren die Art und Weise, wie Updates an Sie ausgeliefert und dokumentiert werden, und ermöglichen eine präzisere Unterscheidung zwischen größeren Feature-Releases und kleineren Hotfixes oder Patches.

*   **Intelligente Unterscheidung zwischen Releases und Patches:** Unser System ist nun in der Lage, automatisch zu erkennen, ob ein Update ein vollständiges "Release" (das native Änderungen oder einen Version-Bump umfasst) oder ein leichter "Patch" (rein serverseitige Code-Updates) ist.
    *   **Nutzen für Dev/Operations:** Dies ermöglicht eine agilere und zielgerichtete Update-Strategie. Patches können schneller und mit weniger Overhead ausgerollt werden, da sie keine vollständigen Neukompilierungen der nativen App erfordern. Für Nutzer bedeutet dies potenziell schnellere Fehlerbehebungen und kleinere Verbesserungen.

*   **Optimiertes Changelog-Management:**
    *   **Anhängen von Patches:** Kleinere Patches werden nun intelligent an den bestehenden Changelog-Eintrag angehängt, anstatt einen neuen, separaten Eintrag zu erstellen. Dies hält das Changelog übersichtlich und fokussiert.
    *   **Dedizierte Release-Einträge:** Volle Releases erhalten weiterhin ihren eigenen, ausführlichen Abschnitt an der Spitze des Changelogs, um ihre Bedeutung und den Umfang der Änderungen hervorzuheben.
    *   **Nutzen für den User/Dev:** Eine klarere und besser strukturierte Historie der Projektentwicklung, die es einfacher macht, den Überblick über die Veränderungen zu behalten und schnell relevante Informationen zu finden.

*   **Gezielte README-Aktualisierungen:** Die Haupt-README des Projekts wird nun nur noch bei echten, umfassenden Releases automatisch aktualisiert. Dies vermeidet unnötige Commits und Versionierungen der README bei kleineren Patch-Updates.
    *   **Nutzen für den Dev/Maintainer:** Reduziert "Noise" in der Git-Historie und stellt sicher, dass die README nur dann angepasst wird, wenn es signifikante Änderungen gibt, die eine neue Zusammenfassung rechtfertigen.

#### Technische Verbesserungen & Code-Pflege

*   **Interne Shorebird App ID Aktualisierung:** Die Shorebird `app_id` in der `shorebird.yaml`-Konfiguration wurde aktualisiert. Dies ist eine routinemäßige interne Anpassung, die keine direkten Auswirkungen auf die Nutzung oder Funktionalität von TechAna hat.
    *   **Nutzen für den Dev/Operations:** Gewährleistet die korrekte Anbindung an unsere Deployment-Infrastruktur für zukünftige Updates.

*   **Code-Bereinigung im Bot-Einstellungen-Bildschirm:** Ein redundanter interner Kommentar im Code für den Bot-Einstellungen-Bildschirm (`lib/ui/bot_settings_screen.dart`) wurde entfernt.
    *   **Nutzen für den Dev:** Trägt zu einer saubereren und leichter wartbaren Codebasis bei. Keine Auswirkungen auf die Benutzeroberfläche.

---

### 2026-02-07 - Update

#### Highlights

*   **Überarbeitete Einstellungen mit Tab-Navigation:** Die gesamte Einstellungsseite wurde für eine deutlich verbesserte Benutzerfreundlichkeit komplett neu strukturiert. Einstellungen sind nun übersichtlich in den Kategorien "Ansicht", "Chart", "Strategie" und "Daten" mittels Tabs organisiert.
    *   **Nutzen für den User:** Das Auffinden spezifischer Einstellungen ist nun intuitiver und schneller, was die Personalisierung von TechAna erheblich vereinfacht und die gesamte App zugänglicher macht.

*   **Erweiterte Filteroptionen im Bot-Dashboard:** Für eine tiefere Analyse Ihrer automatisierten Trades wurden zwei neue Filter hinzugefügt: "Geschlossen +" (für profitable abgeschlossene Trades) und "Geschlossen -" (für verlustreiche abgeschlossene Trades).
    *   **Nutzen für den User:** Dies ermöglicht eine präzisere und schnellere Leistungsanalyse der Bot-Strategien, indem profitable und unrentable Abschlüsse direkt auf einen Blick identifiziert werden können.

*   **Detailliertere Chart-Tooltips mit Datum und Preis:** Die interaktiven Tooltips im Chart zeigen jetzt neben dem Preis auch das genaue Datum des ausgewählten Punktes an und konzentrieren sich auf die Hauptpreislinie.
    *   **Nutzen für den User:** Eine präzisere Dateninterpretation und ein besseres Verständnis von Kursbewegungen im zeitlichen Kontext werden ermöglicht, da detailliertere Informationen direkt im Chart verfügbar sind.

#### Verbesserungen & Technische Details

*   **Stabilere Live-Preisabfrage:** Die Integration der Yahoo Finance API für Live-Kurse wurde optimiert. Statt der `v7/finance/quote`-API wird nun die `v8/finance/chart`-API verwendet. Dies gewährleistet eine konsistentere und zuverlässigere Datenbeschaffung und entfernt die Notwendigkeit, spezifische Marktstatus (Pre/Post-Market) explizit zu prüfen, da `regularMarketPrice` direkt abgefragt wird.
    *   **Nutzen für den User/Dev:** Erhöht die Genauigkeit und Verfügbarkeit von Echtzeit-Kursdaten, was für Handelsentscheidungen und Analysen von entscheidender Bedeutung ist. Entwickler profitieren von einer robusteren Datenintegration.

*   **Optimierungen im Release-Management-Workflow:** Die internen GitHub Actions-Skripte zur Generierung von Release Notes wurden erweitert, um zwischen "Patch"- und "Release"-Updates zu unterscheiden. Patches werden nun konsistent im Changelog angehängt, während größere Releases neue Abschnitte erhalten. Die README wird nur bei vollen Releases aktualisiert.
    *   **Nutzen für den Dev:** Führt zu einem klareren und besser organisierten Changelog, unterscheidet zwischen Hotfixes und Funktionsupdates und reduziert unnötige Commits auf der README.

*   **Dokumentations- und Code-Bereinigung:**
    *   Hinweise zu "automatischen Over-the-Air-Updates (Shorebird)" wurden aus den Installationsanleitungen und der Haupt-README entfernt, da die nahtlose Update-Funktionalität nun ein integraler Bestandteil von TechAna ist und keine gesonderte Erwähnung mehr benötigt.
    *   Eine redundante Sektion in der "Bot-Einstellungen"-UI wurde entfernt, was zu einem saubereren Code und einer potenziell effizienteren UI-Darstellung führt.
    *   **Nutzen für den User/Dev:** Die Dokumentation ist prägnanter und der Code ist aufgeräumter, was die Wartbarkeit und das Verständnis des Projekts verbessert.

---

### 2026-02-05 - Update

Hallo liebe TechAna-Community,

wir freuen uns riesig, euch heute den offiziellen Start von TechAna, Version 1.0.0, bekannt geben zu dürfen! Dies ist ein historischer Moment für unser Projekt und wir sind unglaublich stolz, euch unsere Arbeit der letzten Monate präsentieren zu können.

---

TEIL 1 (Ausführlich für Release Page & Changelog):
## Update-Analyse

Willkommen zum allerersten öffentlichen Release von TechAna – Version 1.0.0!

Dieser initiale Launch markiert einen bedeutenden Meilenstein und bildet das Fundament für eine neue Ära im Bereich des intelligenten Tradings und der Marktanalyse. Nach intensiver Entwicklungsarbeit präsentieren wir euch heute ein robustes Basis-Release, das darauf ausgelegt ist, sowohl erfahrenen Tradern als auch Neueinsteigern ein mächtiges und intuitives Werkzeug an die Hand zu geben.

**Was ist passiert?**
In diesem Zeitraum wurde das gesamte Kernsystem von TechAna von Grund auf konzipiert, entwickelt und stabilisiert. Wir haben uns darauf konzentriert, eine solide Architektur zu schaffen, die nicht nur die aktuellen Anforderungen erfüllt, sondern auch zukünftige Erweiterungen und Integrationen problemlos ermöglicht. Das Ergebnis ist eine Plattform, die Effizienz, Präzision und Automatisierung in den Vordergrund stellt.

**Kern-Features dieses Basis Releases:**

*   **[Feature] Umfassende Trading-Plattform:**
    *   **Beschreibung:** Eine intuitive Benutzeroberfläche ermöglicht den direkten Handel mit verschiedenen Assets. Dazu gehören Funktionen für Orderplatzierung, Positionsverwaltung und Echtzeit-Kursüberwachung.
    *   **Nutzen:** Ermöglicht Benutzern einen einfachen und direkten Zugang zu den Märkten, um Handelsentscheidungen schnell und effizient umzusetzen, ohne zwischen verschiedenen Tools wechseln zu müssen.

*   **[Feature] Tiefgehende Analyse-Tools:**
    *   **Beschreibung:** TechAna bietet eine Reihe von Tools zur technischen und fundamentalen Marktanalyse. Dazu gehören interaktive Charts mit vielfältigen Indikatoren, historische Datenvisualisierung und Anpassungsmöglichkeiten für individuelle Analysen.
    *   **Nutzen:** User können fundierte Handelsentscheidungen auf Basis umfassender Daten und Visualisierungen treffen, Muster erkennen und Marktstimmungen besser einschätzen.

*   **[Feature] Intelligente Bot-Integration:**
    *   **Beschreibung:** Die Plattform ermöglicht die Konfiguration und den Einsatz von automatisierten Trading-Bots. Diese können vorgegebene Strategien 24/7 ausführen, basierend auf vordefinierten Parametern und Signalen.
    *   **Nutzen:** Sparrt den Benutzern Zeit, eliminiert emotionale Handelsfehler und ermöglicht die Ausführung komplexer Strategien rund um die Uhr, selbst wenn sie offline sind. Dies steigert die Effizienz und potenzielle Profitabilität.

**Ausblick:**
Mit v1.0.0 haben wir den Grundstein gelegt. Dies ist nur der Anfang. Wir werden kontinuierlich an der Verbesserung und Erweiterung von TechAna arbeiten, basierend auf eurem Feedback und den Anforderungen des Marktes. Wir freuen uns darauf, diese Reise gemeinsam mit euch zu gestalten!

---

# Update Historie
* 🐛 Fix: Redundanten Code im Bot-Einstellungen-Bildschirm entfernt.

* 🐛 Fix: Einstellungen für den Routineumfang im Bot-Einstellungen-Bildschirm wiederhergestellt.
