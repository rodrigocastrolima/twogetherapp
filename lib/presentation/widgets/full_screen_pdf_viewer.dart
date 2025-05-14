import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class FullScreenPdfViewer extends StatefulWidget {
  final String? pdfUrl;
  final String? pdfName;
  final Uint8List? pdfBytes;

  const FullScreenPdfViewer({
    super.key,
    this.pdfUrl,
    this.pdfName,
    this.pdfBytes,
  }) : assert(
         pdfUrl != null || pdfBytes != null,
         'Either pdfUrl or pdfBytes must be provided',
       );

  @override
  State<FullScreenPdfViewer> createState() => _FullScreenPdfViewerState();
}

class _FullScreenPdfViewerState extends State<FullScreenPdfViewer> {
  String? localPath;
  bool _isLoading = true;
  String? _loadError;
  final Completer<PDFViewController> _controller =
      Completer<PDFViewController>();
  int? pages = 0;
  int? currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final fileName = widget.pdfName ?? const Uuid().v4();
      final dir = await getTemporaryDirectory();
      final safeFileName = fileName.endsWith('.pdf') ? fileName : '$fileName.pdf';
      final file = File('${dir.path}/$safeFileName');

      if (widget.pdfBytes != null) {
        await file.writeAsBytes(widget.pdfBytes!, flush: true);
        if (kDebugMode)
          print('PDF bytes written to temporary file: ${file.path}');
        if (mounted) {
          setState(() {
            localPath = file.path;
            _isLoading = false;
          });
        }
      } else if (widget.pdfUrl != null) {
        final response = await http.get(Uri.parse(widget.pdfUrl!));
        if (response.statusCode == 200) {
          await file.writeAsBytes(response.bodyBytes, flush: true);
          if (kDebugMode)
            print('PDF downloaded to temporary file: ${file.path}');
          if (mounted) {
            setState(() {
              localPath = file.path;
              _isLoading = false;
            });
          }
        } else {
          throw Exception(
            'Failed to load PDF: Status code ${response.statusCode}',
          );
        }
      } else {
        throw Exception('Neither PDF bytes nor URL were provided.');
      }
    } catch (e) {
      print("Error loading PDF: $e");
      if (mounted) {
        setState(() {
          _loadError = "Failed to load PDF: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  // --- Action Handlers ---
  Future<void> _onDownload(BuildContext context) async {
    if (widget.pdfUrl == null) {
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download not available for local data')),
      );
      }
      return;
    }
    final Uri url = Uri.parse(widget.pdfUrl!);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch ${widget.pdfUrl}';
      }
    } catch (e) {
      print('Error launching URL for download: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open PDF link: $e')));
      }
    }
  }

  Future<void> _onShare(BuildContext context) async {
    if (localPath != null) {
      try {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(localPath!)],
          text: widget.pdfName ?? 'PDF Document',
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        );
      } catch (e) {
        if (kDebugMode) print('Error sharing PDF file: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not share PDF file: $e')),
          );
        }
      }
    } else if (widget.pdfUrl != null) {
      try {
        await Share.share('Check out this PDF: ${widget.pdfUrl}');
      } catch (e) {
        print('Error sharing PDF link: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not share PDF link: $e')),
          );
        }
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not share PDF')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool downloadEnabled = widget.pdfUrl != null;
    final bool shareEnabled = localPath != null || widget.pdfUrl != null;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.pdfName ?? 'PDF Viewer', overflow: TextOverflow.ellipsis),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.clear, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (shareEnabled)
              CupertinoButton(
                padding: const EdgeInsets.all(8.0),
                child: const Icon(CupertinoIcons.share, size: 24),
                onPressed: () => _onShare(context),
          ),
            if (downloadEnabled)
              CupertinoButton(
                padding: const EdgeInsets.all(8.0),
                child: const Icon(CupertinoIcons.cloud_download, size: 24),
                onPressed: () => _onDownload(context),
          ),
        ],
      ),
      ),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _loadError!,
            style: TextStyle(
              color: CupertinoDynamicColor.resolve(CupertinoColors.destructiveRed, context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (localPath != null) {
      return PDFView(
        filePath: localPath,
        enableSwipe: true,
        swipeHorizontal: false,
        autoSpacing: true,
        pageFling: true,
        pageSnap: true,
        defaultPage: currentPage ?? 0,
        fitPolicy: FitPolicy.BOTH,
        preventLinkNavigation: false,
        onRender: (_pages) {
          if(mounted) setState(() => pages = _pages);
        },
        onError: (error) {
          if(mounted) setState(() => _loadError = error.toString());
          if (kDebugMode) print(error.toString());
        },
        onPageError: (page, error) {
          if(mounted) setState(() => _loadError = 'Error on page $page: ${error.toString()}');
          if (kDebugMode) print('$page: ${error.toString()}');
        },
        onViewCreated: (PDFViewController pdfViewController) {
          if (!_controller.isCompleted) {
            _controller.complete(pdfViewController);
          }
        },
        onPageChanged: (int? page, int? total) {
          if (kDebugMode) print('page change: $page/$total');
          if(mounted) setState(() => currentPage = page);
        },
      );
    }
    return Center(
      child: Text(
        'Could not load PDF path.',
        style: TextStyle(
          color: CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
        ),
      ),
    );
  }
}
