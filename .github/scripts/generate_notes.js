const fs = require('fs');
const https = require('https');
const { execSync } = require('child_process');

module.exports = async ({ github, context, core }) => {
  // 1. Schalter prüfen (kommt aus Env Variable)
  const useAI = process.env.USE_AI === 'true';
  const geminiKey = process.env.GEMINI_API_KEY;

  // --- FALL 1: AI IST AUS ---
  if (!useAI) {
    console.log("🛑 AI ist deaktiviert. Nutze Standard-Texte.");
    core.setOutput("full_notes", "### 🔧 Wartungsupdate\n\nDies ist ein manuelles Update ohne detaillierte KI-Analyse.\nBitte Installationhinweise beachten.");
    core.setOutput("summary", "🔧 Wartungsupdate (Details folgen)");
    core.setOutput("run_status", "skipped"); // Signal für Workflow, dass wir nichts committen müssen
    return;
  }

  // --- FALL 2: AI IST AN ---
  console.log("🟢 AI ist aktiviert. Starte Analyse...");

  // Gedächtnis laden
  let lastHash = "HEAD~1";
  const stateFile = '.github/ai_state.json';
  let isInitialRun = false;
  
  if (fs.existsSync(stateFile)) {
    try {
      const state = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
      if (state.last_ai_commit && state.last_ai_commit !== "HEAD~1") {
        lastHash = state.last_ai_commit;
        console.log(`📜 Letzter AI-Stand war: ${lastHash}`);
      } else {
        // Wenn Datei da ist, aber leer oder ohne Commit -> Initial Run
        console.log("🆕 State-File existiert, ist aber leer. Initial Release Modus.");
        isInitialRun = true;
      }
    } catch (e) {
      console.log("⚠️ Konnte State-File nicht lesen/parsen. Initial Release Modus.");
      isInitialRun = true;
    }
  } else {
    console.log("🆕 Kein State-File gefunden. Dies ist der erste öffentliche Run (Initial Release).");
    isInitialRun = true;
  }

  // Diff holen (Von letztem AI-Stand bis HEUTE)
  let diff = "";
  if (isInitialRun) {
    diff = "INITIAL_RELEASE_START";
  } else {
    try {
      // Checken, ob der alte Hash überhaupt noch existiert (Fetch-Depth Problem)
      // Wenn nicht, fallback auf HEAD~1
      try {
         execSync(`git cat-file -t ${lastHash}`);
         console.log(`🔍 Vergleiche ${lastHash} bis HEAD`);
         diff = execSync(`git diff ${lastHash} HEAD -- . ":(exclude)pubspec.lock" ":(exclude)*.png"`).toString();
      } catch (e) {
         console.log("⚠️ Alter Hash nicht gefunden (zu alt?), vergleiche nur letzten Commit.");
         diff = execSync(`git diff HEAD~1 HEAD -- . ":(exclude)pubspec.lock"`).toString();
      }
    } catch (error) {
      diff = "Fehler beim Diff";
    }
  }

  if (diff.length > 50000) diff = diff.substring(0, 50000) + "\n... (truncated)";

  // Prompt mit Anweisung zur Zusammenfassung
  const systemInstruction = `
  Du bist Release-Manager für "TechAna".
  
  SITUATION:
  ${isInitialRun ? "Dies ist das allererste öffentliche Release (v1.0.0) dieses Projekts. Es gibt noch keine Historie." : "Wir analysieren alle Änderungen seit dem letzten KI-Bericht."}
  
  AUFGABE:
  ${isInitialRun ? "Erstelle eine freundliche Begrüßung und kündige den Start von TechAna an. Erwähne kurz die Hauptfeatures (Trading, Analyse, Bot) als 'Basis Release'." : "Erstelle deutsche Release Notes basierend auf dem Diff."}
  
  FORMAT (WICHTIG! Nutze genau dieses Trennzeichen):
  
  TEIL 1 (Ausführlich für Release Page & Changelog):
  Überschrift: "## Update-Analyse"
  - Fasse zusammen, was in diesem Zeitraum passiert ist.
  - Wenn es viele Änderungen sind, gruppiere sie sinnvoll (Features, Fixes, Tech).
  - Erkläre den NUTZEN ("Was bringt das dem User/Dev?").
  
  ---SPLIT---
  
  TEIL 2 (Für die Front-README):
  - Max 3 Sätze. Knackig. Was ist das Highlight dieses Zeitraums?
  
  Hier ist der Code-Diff:
  `;

  const requestBody = JSON.stringify({
    contents: [{ parts: [{ text: systemInstruction + "\n" + diff }] }]
  });

  const options = {
    hostname: 'generativelanguage.googleapis.com',
    path: `/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  };

  await new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        if (res.statusCode !== 200) return reject(`API Error: ${res.statusCode} ${body}`);
        
        try {
          const json = JSON.parse(body);
          const txt = json.candidates[0].content.parts[0].text;
          const parts = txt.split("---SPLIT---");
          
          const fullNotes = parts[0].trim();
          const summary = parts[1] ? parts[1].trim() : "Update verfügbar.";
          
          core.setOutput("full_notes", fullNotes);
          core.setOutput("summary", summary);
          core.setOutput("run_status", "success");
          
          // NEUEN STATE SPEICHERN (Nur im File, Commit macht der Workflow)
          // Wir speichern den aktuellen HEAD als neuen "letzten Stand"
          const currentHead = execSync('git rev-parse HEAD').toString().trim();
          fs.writeFileSync(stateFile, JSON.stringify({ last_ai_commit: currentHead }, null, 2));
          
          resolve();
        } catch (e) { reject(e); }
      });
    });
    req.write(requestBody);
    req.end();
  });
};