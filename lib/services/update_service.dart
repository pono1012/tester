import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _repoUrl = "https://github.com/pono1012/techana";
  static const String _versionJsonUrl = "$_repoUrl/releases/latest/download/version.json";
  static const String _apkUrl = "$_repoUrl/releases/latest/download/TechAna-android.apk";
  static const String _iosUrl = "$_repoUrl/releases/latest/download/TechAna-iOS.ipa";
  static const String _windowsUrl = "$_repoUrl/releases/latest/download/TechAna-windows.zip";
  static const String _macosUrl = "$_repoUrl/releases/latest/download/TechAna-macos.zip";
  static const String _linuxUrl = "$_repoUrl/releases/latest/download/TechAna-linux.zip";

  /// Prüft auf Updates und zeigt ggf. einen Dialog an.
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // 1. Lokale Version ermitteln
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String localVersion = packageInfo.version;
      if (packageInfo.buildNumber.isNotEmpty) {
        localVersion += "+${packageInfo.buildNumber}";
      }
      debugPrint("UpdateService: Lokal: $localVersion");

      // 2. Remote Version laden (mit Cache Busting gegen alte Daten)
      final url = Uri.parse("$_versionJsonUrl?t=${DateTime.now().millisecondsSinceEpoch}");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        String remoteVersion = json['version'];
        String notes = json['release_notes'] ?? "Neue Version verfügbar.";
        debugPrint("UpdateService: Remote: $remoteVersion");

        // 3. Vergleich
        if (_isNewer(remoteVersion, localVersion)) {
          debugPrint("UpdateService: Update verfügbar!");
          if (context.mounted) {
            _showUpdateDialog(context, remoteVersion, notes);
          }
        }
      }
    } catch (e) {
      debugPrint("Update Check Fehler: $e");
    }
  }

  /// Versionsvergleich mit Build-Nummer Support (x.y.z+n)
  bool _isNewer(String remote, String local) {
    try {
      // Helper: Trennt "1.0.0+18" in ["1.0.0", "18"]
      List<String> splitBuild(String v) {
        if (v.contains('+')) return v.split('+');
        return [v, '0'];
      }

      final rParts = splitBuild(remote);
      final lParts = splitBuild(local);

      final rVer = rParts[0];
      final lVer = lParts[0];
      
      final rBuild = int.tryParse(rParts[1]) ?? 0;
      final lBuild = int.tryParse(lParts[1]) ?? 0;

      // Hauptversion vergleichen (x.y.z)
      // Entferne Suffixe wie "-beta" für den Integer-Vergleich
      String cleanVer(String v) => v.split('-')[0];
      
      List<int> parse(String v) => cleanVer(v).split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final rVerNums = parse(rVer);
      final lVerNums = parse(lVer);

      for (int i = 0; i < rVerNums.length; i++) {
        if (i >= lVerNums.length) return true;
        if (rVerNums[i] > lVerNums[i]) return true;
        if (rVerNums[i] < lVerNums[i]) return false;
      }
      
      // Wenn Hauptversion gleich ist, entscheidet die Build Number
      if (rVerNums.length == lVerNums.length) {
        return rBuild > lBuild;
      }

      return false;
    } catch (e) {
      debugPrint("Version Compare Error: $e");
      return false;
    }
  }

  void _showUpdateDialog(BuildContext context, String version, String notes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Update verfügbar: v$version"),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notes),
                const SizedBox(height: 16),
                const Text(
                  "Wähle deine Version zum Download:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildDownloadButton(ctx, "🤖 Android (.apk)", _apkUrl),
                _buildDownloadButton(ctx, "🪟 Windows (.zip)", _windowsUrl),
                _buildDownloadButton(ctx, "🍏 macOS (.zip)", _macosUrl),
                _buildDownloadButton(ctx, "🐧 Linux (.zip)", _linuxUrl),
                _buildDownloadButton(ctx, "📱 iOS (.ipa)", _iosUrl),
                const Divider(),
                Center(
                  child: TextButton(
                    onPressed: () => _launchBrowser(),
                    child: const Text("Zur GitHub Release Seite"),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Später"),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context, String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.download),
          label: Text(label),
          onPressed: () async {
            final uri = Uri.parse(url);
            try {
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                debugPrint("Konnte $url nicht öffnen");
              }
            } catch (e) {
              debugPrint("Fehler beim Öffnen von $url: $e");
            }
          },
        ),
      ),
    );
  }

  Future<void> _launchBrowser() async {
    await launchUrl(
      Uri.parse("$_repoUrl/releases/latest"),
      mode: LaunchMode.externalApplication,
    );
  }
}
