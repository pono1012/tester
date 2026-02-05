import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/data_service.dart';

class NewsScreen extends StatefulWidget {
  final String symbol;
  const NewsScreen({super.key, required this.symbol});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsItem> _news = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    final ds = DataService();
    final items = await ds.fetchNews(widget.symbol);
    if (mounted) {
      setState(() {
        _news = items;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("News: ${widget.symbol}")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _news.isEmpty
              ? const Center(
                  child: Text("Keine aktuellen Nachrichten gefunden."))
              : ListView.separated(
                  itemCount: _news.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = _news[index];
                    return ListTile(
                      title: Text(item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(item.pubDate),
                      trailing: const Icon(Icons.open_in_new, size: 16),
                      onTap: () => _launchUrl(item.link),
                    );
                  },
                ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("Konnte $url nicht öffnen");
    }
  }
}
