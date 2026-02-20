import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class PdfViewScreen extends StatefulWidget {
  final String pdfUrl;
  final String title;

  const PdfViewScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    if (!kIsWeb) {
      // On mobile/desktop, use network directly (handled by Syncfusion, but we want uniformity?)
      // Syncfusion network is fine for native.
      // But wait, Syncfusion network constructor was removed in previous step.
      // We must fetch bytes for Native too if we use .memory constructor.
      // Or we can revert to .network for native?
      // Actually, standard http get is fine for native.
      try {
        final response = await http.get(Uri.parse(widget.pdfUrl));
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _pdfBytes = response.bodyBytes;
              _isLoading = false;
            });
          }
        } else {
          throw Exception('HTTP ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = e.toString();
          });
        }
      }
      return;
    }

    // Web Proxy Rotation
    final proxies = [
      (String url) => 'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(url)}',
      (String url) => 'https://corsproxy.io/?${Uri.encodeComponent(url)}',
      (String url) => 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}',
    ];

    for (var i = 0; i < proxies.length; i++) {
      try {
        final proxyUrl = proxies[i](widget.pdfUrl);
        debugPrint('PdfViewScreen: Trying proxy ${i + 1}: $proxyUrl');
        
        final response = await http.get(Uri.parse(proxyUrl));
        
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _pdfBytes = response.bodyBytes;
              _isLoading = false;
            });
          }
          return; // Success!
        } else {
          debugPrint('Proxy ${i + 1} failed with status ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Proxy ${i + 1} failed: $e');
      }
    }

    // All failed
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch PDF via proxies.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface.withAlpha(240),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: AppTheme.textPrimary),
            tooltip: 'Open in Browser',
            onPressed: () => _launchInBrowser(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text('Fetching PDF...', style: TextStyle(color: AppTheme.textDim)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.orange),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load PDF.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.textDim),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Web proxies often limit file sizes.',
                          style: TextStyle(color: AppTheme.textDim, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _launchInBrowser,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open in Browser'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SfPdfViewer.memory(
                  _pdfBytes!,
                  controller: _pdfViewerController,
                ),
    );
  }

  Future<void> _launchInBrowser() async {
    final uri = Uri.parse(widget.pdfUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
