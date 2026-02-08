const fs = require('fs');
const https = require('https');
const { execSync } = require('child_process');

module.exports = async ({ github, context, core }) => {
  // 1. Schalter prüfen (kommt aus Env Variable)
  const useAI = process.env.USE_AI === 'true';
  const geminiKey = process.env.GEMINI_API_KEY;
  const patchFile = '.github/current_patch_notes.md'; // Zwischenspeicher für Patches

  // --- FALL 1: AI IST AUS ---
  if (!useAI) {
    console.log("🛑 AI ist deaktiviert. Nutze Standard-Texte.");
    core.setOutput("full_notes", "### 🔧 Wartungsupdate\n\nDies ist ein manuelles Update ohne detaillierte KI-Analyse.\nBitte Installationhinweise beachten.");
    core.setOutput("summary", "🔧 Wartungsupdate (Details folgen)");
    core.setOutput("run_status", "skipped"); // Signal für Workflow, dass wir nichts committen müssen
    core.setOutput("update_type", "patch");
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
  let isPatch = false;
  let changedFilesSection = ""; // NEU: Speicher für die Dateiliste
  if (isInitialRun) {
    diff = "INITIAL_RELEASE_START";
  } else {
    try {
      // Checken, ob der alte Hash überhaupt noch existiert (Fetch-Depth Problem)
      // Wenn nicht, fallback auf HEAD~1
      try {
         execSync(`git cat-file -t ${lastHash}`);
         console.log(`🔍 Vergleiche ${lastHash} bis HEAD`);

         // --- Patch-Erkennung ---
         const rawFileList = execSync(`git diff ${lastHash} HEAD --name-only`).toString();
         const filesToExclude = ['.github/ai_state.json', '.github/current_patch_notes.md', 'CHANGELOG.md'];
         const fileList = rawFileList.split('\n').filter(line => {
            const trimmedLine = line.trim();
            return trimmedLine !== '' && !filesToExclude.includes(trimmedLine);
         });
         const releaseTriggers = ['android/', 'ios/', 'windows/', 'macos/', 'linux/', 'pubspec.yaml'];
         const hasReleaseChanges = fileList.some(file => releaseTriggers.some(trigger => file.startsWith(trigger)));

         if (!hasReleaseChanges && fileList.length > 0) {
           isPatch = true;
           console.log("🩹 Patch-Modus erkannt: Keine nativen Änderungen oder Version-Bumps.");
         }

         // --- Diff und Dateiliste für die KI und Notes generieren ---
         diff = execSync(`git diff ${lastHash} HEAD -- . ":(exclude)pubspec.lock" ":(exclude)*.png"`).toString();
         
         if (fileList.length > 0) {
            changedFilesSection = "### 📂 Geänderte Dateien\n";
            changedFilesSection += fileList.map(f => `- \`${f}\``).join('\n');
         }
         // -----------------------
      } catch (e) {
         console.log("⚠️ Alter Hash nicht gefunden (zu alt?), vergleiche nur letzten Commit.");
         lastHash = "HEAD~1"; // Setze den Hash für die Logik zurück

         // --- Führe die Logik erneut aus mit dem Fallback-Hash ---
         const rawFileList = execSync(`git diff ${lastHash} HEAD --name-only`).toString();
         const filesToExclude = ['.github/ai_state.json', '.github/current_patch_notes.md', 'CHANGELOG.md'];
         const fileList = rawFileList.split('\n').filter(line => {
            const trimmedLine = line.trim();
            return trimmedLine !== '' && !filesToExclude.includes(trimmedLine);
         });
         const releaseTriggers = ['android/', 'ios/', 'windows/', 'macos/', 'linux/', 'pubspec.yaml'];
         const hasReleaseChanges = fileList.some(file => releaseTriggers.some(trigger => file.startsWith(trigger)));

         if (!hasReleaseChanges && fileList.length > 0) {
           isPatch = true;
           console.log("🩹 Patch-Modus erkannt (im Fallback): Keine nativen Änderungen.");
         }

         diff = execSync(`git diff ${lastHash} HEAD -- . ":(exclude)pubspec.lock" ":(exclude)*.png"`).toString();
         
         if (fileList.length > 0) {
            changedFilesSection = "### 📂 Geänderte Dateien\n";
            changedFilesSection += fileList.map(f => `- \`${f}\``).join('\n');
         }
      }
    } catch (error) {
      diff = "Fehler beim Diff";
    }
  }

  if (diff.length > 50000) diff = diff.substring(0, 50000) + "\n... (truncated)";

  // Prompt mit Anweisung zur Zusammenfassung
  let systemInstruction = "";

  if (isPatch) {
    // --- KURZER PATCH PROMPT ---
    systemInstruction = `
  Du bist Release-Manager für "TechAna".
  SITUATION:
  Dies ist ein "Shorebird Patch" (Hotfix).
  
  AUFGABE:
  Erstelle GENAU EINEN Listenpunkt (Bullet Point) für diesen Fix.
  Keine Einleitung, kein "Hier ist...", nur der Punkt.
  
  FORMAT:
  TEIL 1:
  * 🐛 Fix: [Beschreibung] (oder ⚡ Performance: ...) (Kein weiterer Text!)
    `;
  } else {
    // --- NORMALER RELEASE PROMPT ---
    systemInstruction = `
  Du bist Release-Manager für "TechAna".
  
  SITUATION:
  ${isInitialRun ? "Dies ist das allererste öffentliche Release (v1.0.0) dieses Projekts. Es gibt noch keine Historie." : "Wir analysieren alle Änderungen seit dem letzten KI-Bericht."}
  
  AUFGABE:
  ${isInitialRun ? "Erstelle eine freundliche Begrüßung und kündige den Start von TechAna an." : "Erstelle professionelle, ausführliche Release Notes."}
  
  FORMAT (WICHTIG! Nutze genau dieses Trennzeichen):
  
  TEIL 1 (Ausführlich für Release Page & Changelog):
  (Starte direkt mit dem Text oder kleinen Zwischenüberschriften wie "#### Highlights". Keine H1/H2/H3 Überschriften!)
  - Fasse zusammen, was passiert ist.
  - Gruppiere sinnvoll (Features, Fixes).
  - Erkläre den NUTZEN ("Was bringt das dem User/Dev?").
  
  ---SPLIT---
  
  TEIL 2 (Für die Front-README):
  - Schreibe eine knackige Zusammenfassung (Max 3 Sätze) für den Header der README. Fokus auf Mehrwert.
  
  Hier ist der Code-Diff:
  `;
  }

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
          const text = json.candidates[0].content.parts[0].text;

          if (isPatch) {
            // --- PATCH LOGIK ---
            const newPoint = text.trim(); // AI gibt nur den Bullet Point zurück
            const now = new Date();
            const date = now.toLocaleDateString('de-DE', { day: '2-digit', month: '2-digit', year: 'numeric' });
            const time = now.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });

            // Kompletter Block für diesen Patch
            let patchBlock = `### 🩹 Patch vom ${date} um ${time} Uhr\n\n${newPoint}\n\n`;
            if (changedFilesSection) {
                patchBlock += `${changedFilesSection}\n\n---\n`;
            }

            // Bestehende Patch-Notes laden und neuen Block voranstellen
            let existingPatches = "";
            if (fs.existsSync(patchFile)) {
                existingPatches = fs.readFileSync(patchFile, 'utf8');
            }
            fs.writeFileSync(patchFile, patchBlock + existingPatches);

            core.setOutput("full_notes", newPoint); // Fürs Changelog reicht der Punkt
            core.setOutput("summary", "Patch Update");
            core.setOutput("update_type", "patch");
          } else {
            // --- RELEASE LOGIK ---
            const parts = text.split("---SPLIT---");
            let fullNotes = parts[0].trim();
            const summary = parts[1] ? parts[1].trim() : "Großes Update";

            if (changedFilesSection) {
                fullNotes += `\n\n${changedFilesSection}`;
            }
            // Patch-Datei leeren (Reset für neuen Zyklus)
            fs.writeFileSync(patchFile, "");
            core.setOutput("full_notes", fullNotes);
            core.setOutput("summary", summary);
            core.setOutput("update_type", "release");
          }

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