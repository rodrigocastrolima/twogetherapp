import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:file_saver/file_saver.dart';
import 'package:mime/mime.dart';

// Conditional imports for web functionality
import 'secure_file_viewer_stub.dart'
  if (dart.library.html) 'secure_file_viewer_web.dart';

// Use correct absolute import path for providers
import 'package:twogether/features/opportunity/presentation/providers/opportunity_providers.dart';

final logger = Logger();

class SecureFileViewer extends ConsumerStatefulWidget {
  // Support both Salesforce files and direct URLs
  final String? contentVersionId;
  final String? directUrl;
  final String title;
  final String? fileType; // Optional hint from SalesforceFile
  final bool isResellerContext; // New parameter to specify reseller context

  const SecureFileViewer({
    super.key,
    this.contentVersionId,
    this.directUrl,
    required this.title,
    this.fileType,
    this.isResellerContext = false, // Default to admin/OAuth context
  }) : assert(contentVersionId != null || directUrl != null, 'Either contentVersionId or directUrl must be provided');

  // Named constructors for convenience
  const SecureFileViewer.fromSalesforce({
    super.key,
    required this.contentVersionId,
    required this.title,
    this.fileType,
    this.isResellerContext = false,
  }) : directUrl = null;

  const SecureFileViewer.fromUrl({
    super.key,
    required String url,
    required this.title,
    this.fileType,
  }) : contentVersionId = null,
       directUrl = url,
       isResellerContext = false;

  @override
  ConsumerState<SecureFileViewer> createState() => _SecureFileViewerState();
}

class _SecureFileViewerState extends ConsumerState<SecureFileViewer> {
  bool _isLoading = true;
  String? _error;

  // State for loaded data
  Uint8List? _fileBytes;
  String? _contentType;
  String? _fileExtension; // <-- ADD state for extension
  String? _localTempFilePath; // For PDFView or saving

  final Completer<PDFViewController> _pdfViewController =
      Completer<PDFViewController>();
  int? _pdfCurrentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.contentVersionId != null) {
        // Load from Salesforce
        await _loadFromSalesforce();
      } else if (widget.directUrl != null) {
        // Load from direct URL
        await _loadFromUrl();
      } else {
        throw Exception('No content source provided');
      }
    } catch (e, s) {
      logger.e('Error in _loadFile', error: e, stackTrace: s);
      if (mounted) {
        setState(() {
          _error = 'An unexpected error occurred: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFromSalesforce() async {
    // Choose the appropriate service based on context
    final opportunityService = widget.isResellerContext
        ? ref.read(resellerOpportunityServiceProvider)
        : ref.read(salesforceOpportunityServiceProvider);
    
    // Explicitly define the expected return type
    final ({
      Uint8List? fileData,
      String? contentType,
      String? fileExtension,
      String? error,
      bool sessionExpired,
    })
    result = widget.isResellerContext
        ? await opportunityService.downloadFileForReseller(
            contentVersionId: widget.contentVersionId!,
          )
        : await opportunityService.downloadFile(
      contentVersionId: widget.contentVersionId!,
    );

    if (!mounted) return;

    // Access fields from the explicitly typed record
    if (result.fileData != null) {
      _fileBytes = result.fileData;
      _contentType = result.contentType;
      _fileExtension = result.fileExtension;
      logger.i(
        'File loaded successfully from Salesforce (${widget.isResellerContext ? 'Reseller' : 'Admin'} context). Type: $_contentType, Extension: $_fileExtension',
      );

      await _processPdfIfNeeded();

      setState(() {
        _isLoading = false;
      });
    } else {
      logger.w('Salesforce file download failed (${widget.isResellerContext ? 'Reseller' : 'Admin'} context)', error: result.error);
      setState(() {
        _error = result.error ?? 'Failed to load file data from Salesforce.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFromUrl() async {
    try {
      final response = await http.get(Uri.parse(widget.directUrl!));
      
      if (response.statusCode == 200) {
        _fileBytes = response.bodyBytes;
        _contentType = response.headers['content-type'] ?? _guessContentTypeFromUrl(widget.directUrl!);
        _fileExtension = _extractExtensionFromUrl(widget.directUrl!);
        
        logger.i(
          'File loaded successfully from URL. Type: $_contentType, Extension: $_fileExtension',
        );

        await _processPdfIfNeeded();

        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load file: HTTP ${response.statusCode}');
      }
    } catch (e) {
      logger.w('URL file download failed', error: e);
      setState(() {
        _error = 'Failed to load file from URL: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _processPdfIfNeeded() async {
    // Determine if PDF and save
    bool isPdf = _fileExtension?.toLowerCase() == 'pdf';

    // Fallback to content type if extension is missing/unknown
    if (!isPdf && _contentType?.toLowerCase() == 'application/pdf') {
      isPdf = true;
    }

    // If it's identified as a PDF, save to temp file for PDFView
    if (isPdf && _fileBytes != null) {
      logger.i('Identified as PDF, saving to temporary file...');
      // Use extension in temp filename if possible
      final tempFileName =
          _fileExtension != null
              ? "${widget.title}.$_fileExtension"
              : widget.title;
      await _saveBytesToTempFile(_fileBytes!, tempFileName);
    }
  }

  String _guessContentTypeFromUrl(String url) {
    final extension = _extractExtensionFromUrl(url);
    switch (extension?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  String? _extractExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final lastDot = path.lastIndexOf('.');
      if (lastDot != -1 && lastDot < path.length - 1) {
        return path.substring(lastDot + 1).split('?')[0]; // Remove query params
      }
    } catch (e) {
      logger.w('Error extracting extension from URL', error: e);
    }
    return null;
  }

  Future<void> _saveBytesToTempFile(Uint8List bytes, String fileName) async {
    if (kDebugMode) {
      logger.d('_saveBytesToTempFile called. kIsWeb: $kIsWeb');
    }
    if (kIsWeb) {
      // For web, create a blob and download the file
      if (kDebugMode) {
        logger.d('Web platform detected, creating blob for download');
      }
      return;
    }

    // For mobile platforms, save to temp directory
      final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(bytes);
        setState(() {
      _localTempFilePath = file.path;
        });
  }

  // --- Action Handlers (Placeholder) ---
  Future<void> _onShare(BuildContext context) async {
    if (_fileBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum ficheiro disponível para partilhar.')),
      );
      return;
    }

    try {
      // Determine file extension and name
      String fileExtension = '';
      if (_fileExtension?.isNotEmpty == true) {
        fileExtension = _fileExtension!.startsWith('.') 
            ? _fileExtension! 
            : '.$_fileExtension';
      } else if (_contentType != null) {
        // Try to get extension from MIME type
        final mimeExtension = extensionFromMime(_contentType!);
        if (mimeExtension != null) {
          fileExtension = '.$mimeExtension';
        }
      }

      // Sanitize filename and ensure it has an extension
      String sanitizedTitle = widget.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      if (!sanitizedTitle.endsWith(fileExtension) && fileExtension.isNotEmpty) {
        sanitizedTitle += fileExtension;
      }

      // If we already have a temp file, use it directly
      if (_localTempFilePath != null && await File(_localTempFilePath!).exists()) {
        final xfile = XFile(_localTempFilePath!);
        await Share.shareXFiles([xfile], text: 'Sharing ${widget.title}');
        return;
      }

      // Otherwise, create a temporary file for sharing
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, sanitizedTitle));
      
      // Write file bytes to temp file
      await tempFile.writeAsBytes(_fileBytes!);
      
      // Create XFile and share
      final xfile = XFile(tempFile.path);
      await Share.shareXFiles([xfile], text: 'A partilhar ${widget.title}');
      
      // Clean up temp file after a delay (give time for sharing to complete)
      Future.delayed(const Duration(seconds: 30), () {
        try {
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        } catch (e) {
          logger.w('Could not clean up temporary share file', error: e);
        }
      });

    } catch (e) {
      logger.e('Error sharing file', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao partilhar ficheiro: $e')),
      );
    }
  }

  Future<void> _onDownload(BuildContext context) async {
    if (_fileBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuns dados de ficheiro para transferir.')),
      );
      return;
    }

    try {
      // Determine file extension
      String fileExtension = '';
      if (_fileExtension?.isNotEmpty == true) {
        fileExtension = _fileExtension!.replaceAll('.', ''); // Remove dot for file_saver
      } else if (_contentType != null) {
        // Try to get extension from MIME type
        final mimeExtension = extensionFromMime(_contentType!);
        if (mimeExtension != null) {
          fileExtension = mimeExtension;
        }
      }

      // Fallback to content type for common cases
      if (fileExtension.isEmpty && _contentType != null) {
        if (_contentType!.contains('pdf')) {
          fileExtension = 'pdf';
        } else if (_contentType!.startsWith('image/')) {
          final parts = _contentType!.split('/');
          if (parts.length > 1) {
            fileExtension = parts[1].toLowerCase();
          }
        }
      }

      // Sanitize filename (remove extension if already present)
      String sanitizedTitle = widget.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      if (sanitizedTitle.toLowerCase().endsWith('.$fileExtension')) {
        sanitizedTitle = sanitizedTitle.substring(0, sanitizedTitle.length - fileExtension.length - 1);
      }

      // Add extension if not present
      if (fileExtension.isNotEmpty) {
        sanitizedTitle = '$sanitizedTitle.$fileExtension';
      }

      if (kIsWeb) {
        // Use the web-specific download function
        downloadFile(_fileBytes!, sanitizedTitle, _contentType ?? 'application/octet-stream');
      } else {
        // Use file_saver for mobile platforms
        await FileSaver.instance.saveFile(
          name: sanitizedTitle,
          bytes: _fileBytes!,
          mimeType: MimeType.other,
          ext: fileExtension,
        );
      }
    } catch (e) {
      logger.e('Error downloading file', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao transferir ficheiro: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (kDebugMode) {
      logger.d(
        'SecureFileViewer BUILD: isLoading=$_isLoading, error=$_error, localPath=$_localTempFilePath',
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        middle: Text(
          widget.title, 
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(
            CupertinoIcons.clear, 
            size: 28,
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Only show share button for non-Salesforce files (direct URLs)
            // Salesforce files have limitations in web environment with path_provider
            // Users can still download the file using the download button
            if (widget.contentVersionId == null)
            CupertinoButton(
              padding: const EdgeInsets.all(8.0),
              onPressed: _isLoading || (_localTempFilePath == null && _fileBytes == null)
                    ? null
                    : () => _onShare(context),
              child: Icon(
                CupertinoIcons.share, 
                size: 24,
                color: theme.colorScheme.onSurface,
              ),
          ),
            CupertinoButton(
              padding: const EdgeInsets.all(8.0),
              onPressed: _isLoading || _fileBytes == null
                    ? null
                    : () => _onDownload(context),
              child: Icon(
                CupertinoIcons.cloud_download, 
                size: 24,
                color: theme.colorScheme.onSurface,
              ),
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

    if (_error != null) {
      // Optionally handle session expired differently (e.g., show button to re-login)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Determine effective type, prioritizing fileExtension
    bool usePdfViewer = _fileExtension?.toLowerCase() == 'pdf';
    bool useImageViewer = [
      'png',
      'jpg',
      'jpeg',
      'gif',
      'bmp',
      'webp',
    ].contains(_fileExtension?.toLowerCase());

    // Fallback to contentType if extension didn't match
    if (!usePdfViewer && !useImageViewer) {
      final effectiveContentType = _contentType?.toLowerCase();
      if (effectiveContentType == 'application/pdf') {
        usePdfViewer = true;
      } else if (effectiveContentType?.startsWith('image/') == true) {
        useImageViewer = true;
      }
    }

    // Removed fallback to fileTypeHint as extension should be primary

    // --- Display Content based on Determined Type ---
    if (usePdfViewer && _fileBytes != null) {
      if (kIsWeb) {
        // For web, use the web-specific openBlob function
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (kDebugMode) {
            logger.d('Web platform detected, opening PDF in new tab');
          }
          openBlob(_fileBytes!, _contentType ?? 'application/pdf');
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CupertinoActivityIndicator(),
              const SizedBox(height: 16),
              Text(
                'A abrir PDF numa nova aba...',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      } else {
        // For mobile, use PDFView
        return PDFView(
          filePath: _localTempFilePath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          pageSnap: true,
          defaultPage: _pdfCurrentPage ?? 0,
          fitPolicy: FitPolicy.BOTH,
          preventLinkNavigation: false,
          onRender: (pages) {
            setState(() {
              // _pdfPages = pages; // Removed unused field
            });
          },
          onError: (error) {
            logger.e("PDFView Error", error: error);
          },
          onPageError: (page, error) {
            logger.e("PDFView Page Error", error: {'page': page, 'error': error});
          },
          onViewCreated: (PDFViewController pdfViewController) {
            if (!_pdfViewController.isCompleted) {
              _pdfViewController.complete(pdfViewController);
            }
          },
          onPageChanged: (int? page, int? total) {
            setState(() {
              _pdfCurrentPage = page;
            });
          },
        );
      }
    } else if (useImageViewer && _fileBytes != null) {
      // Use Image.memory for images
      return Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(
            _fileBytes!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              logger.e(
                'Error rendering image',
                error: error,
                stackTrace: stackTrace,
              );
              return Center(
                child: Text(
                  'Não foi possível mostrar a imagem.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            },
          ),
        ),
      );
    }

    // Fallback for other types or if something went wrong
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
            Icon(
              CupertinoIcons.doc_text_fill, // Using a Cupertino icon
              size: 60,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          const SizedBox(height: 16),
          Text(
            // Show extension if available, otherwise content type
            'Não é possível mostrar o tipo de ficheiro: ${_fileExtension ?? _contentType ?? 'Desconhecido'}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _isLoading || _fileBytes == null
                    ? null
                    : () => _onDownload(context),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.cloud_download_fill),
                  SizedBox(width: 8),
                  Text('Transferir Ficheiro'),
                ],
              ),
          ),
        ],
      ),
      ),
    );
  }
}
