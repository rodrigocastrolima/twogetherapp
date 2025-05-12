import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart'; // For PDF display
import 'package:share_plus/share_plus.dart';
// import 'package:file_saver/file_saver.dart'; // Needed for download action

// Correct the import path to point to /services/
import 'package:twogether/features/opportunity/data/services/opportunity_service.dart';
// Use correct absolute import path for providers
import 'package:twogether/features/opportunity/presentation/providers/opportunity_providers.dart';

final logger = Logger();

class SecureFileViewer extends ConsumerStatefulWidget {
  final String contentVersionId;
  final String title;
  final String? fileType; // Optional hint from SalesforceFile

  const SecureFileViewer({
    super.key,
    required this.contentVersionId,
    required this.title,
    this.fileType,
  });

  @override
  ConsumerState<SecureFileViewer> createState() => _SecureFileViewerState();
}

class _SecureFileViewerState extends ConsumerState<SecureFileViewer> {
  bool _isLoading = true;
  String? _error;
  bool _sessionExpired = false;

  // State for loaded data
  Uint8List? _fileBytes;
  String? _contentType;
  String? _fileExtension; // <-- ADD state for extension
  String? _localTempFilePath; // For PDFView or saving

  final Completer<PDFViewController> _pdfViewController =
      Completer<PDFViewController>();
  int? _pdfPages = 0;
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
      _sessionExpired = false;
    });

    try {
      final opportunityService = ref.read(salesforceOpportunityServiceProvider);
      // Explicitly define the expected return type
      final ({
        Uint8List? fileData,
        String? contentType,
        String? fileExtension,
        String? error,
        bool sessionExpired,
      })
      result = await opportunityService.downloadFile(
        contentVersionId: widget.contentVersionId,
      );

      if (!mounted) return;

      // Access fields from the explicitly typed record
      if (result.fileData != null) {
        _fileBytes = result.fileData;
        _contentType = result.contentType;
        _fileExtension = result.fileExtension; // Should resolve now
        logger.i(
          'File loaded successfully. Type: $_contentType, Extension: $_fileExtension',
        );

        // --- MODIFIED: Determine if PDF and save ---
        // Prioritize file extension if available
        bool isPdf = _fileExtension?.toLowerCase() == 'pdf';

        // Fallback to content type if extension is missing/unknown
        if (!isPdf && _contentType?.toLowerCase() == 'application/pdf') {
          isPdf = true;
        }
        // Original fallback based on title hint (less reliable)
        // if (!isPdf && widget.fileType?.toLowerCase() == 'pdf') {
        //   isPdf = true;
        // }

        // If it's identified as a PDF, save to temp file for PDFView
        if (isPdf) {
          logger.i('Identified as PDF, saving to temporary file...');
          // Use extension in temp filename if possible
          final tempFileName =
              _fileExtension != null
                  ? "${widget.title}.${_fileExtension}"
                  : widget.title;
          await _saveBytesToTempFile(result.fileData!, tempFileName);
        }
        // --- END MODIFICATION ---

        // For images, we can use _fileBytes directly with Image.memory
        setState(() {
          _isLoading = false;
        });
      } else {
        logger.w('File download failed', error: result.error);
        setState(() {
          _error = result.error ?? 'Failed to load file data.';
          _sessionExpired = result.sessionExpired;
          _isLoading = false;
        });
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

  Future<void> _saveBytesToTempFile(Uint8List bytes, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Keep sanitization, but the filename now includes extension
      final safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final file = File('${tempDir.path}/$safeFileName');
      await file.writeAsBytes(bytes);
      final tempPath = file.path; // Store path before setState
      if (mounted) {
        setState(() {
          _localTempFilePath = tempPath;
        });
        print(
          '*** SecureFileViewer SAVED TEMP FILE: _localTempFilePath is set to "$_localTempFilePath" ***',
        );
      }
    } catch (e) {
      logger.e('Error saving temp file', error: e);
      if (mounted) {
        setState(() {
          _error = "Could not prepare file for viewing.";
        });
      }
    }
  }

  // --- Action Handlers (Placeholder) ---
  Future<void> _onShare(BuildContext context) async {
    if (_localTempFilePath != null) {
      try {
        final xfile = XFile(_localTempFilePath!);
        await Share.shareXFiles([xfile], text: 'Sharing ${widget.title}');
      } catch (e) {
        logger.e('Error sharing file', error: e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing file: $e')));
      }
    } else if (_fileBytes != null &&
        _contentType?.startsWith('image/') == true) {
      // For images, need to save to temp file first before sharing
      // TODO: Implement image temp save and share
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image sharing not implemented yet.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file available to share.')),
      );
    }
  }

  Future<void> _onDownload(BuildContext context) async {
    // TODO: Implement download using file_saver
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download not implemented yet.')),
    );
    if (_fileBytes != null && _contentType != null) {
      // Example using file_saver (requires adding dependency)
      /*
      try {
        // Determine file extension
        final extension = _contentType!.split('/').last; // Basic extension
        await FileSaver.instance.saveFile(
          name: widget.title, 
          bytes: _fileBytes!,
          ext: extension, 
          mimeType: MimeType.custom, // Or map common types
          customMimeType: _contentType
        );
      } catch (e) {
        logger.e('Error saving file', error: e);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
      } 
      */
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No file data to save.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      '*** SecureFileViewer BUILD: isLoading=$_isLoading, error=$_error, localPath=$_localTempFilePath ***',
    );

    return Scaffold(
      backgroundColor: Colors.grey[300],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Theme.of(context).primaryColor),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.black87),
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share File',
            // Disable if loading or no file
            onPressed:
                _isLoading || (_localTempFilePath == null && _fileBytes == null)
                    ? null
                    : () => _onShare(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Save File',
            // Disable if loading or no file
            onPressed:
                _isLoading || _fileBytes == null
                    ? null
                    : () => _onDownload(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      // Optionally handle session expired differently (e.g., show button to re-login)
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: TextStyle(color: Colors.red[700]),
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
    if (usePdfViewer && _localTempFilePath != null) {
      // Use PDFView with the temporary file path
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
            _pdfPages = pages;
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
              return const Center(
                child: Text(
                  'Could not display image.',
                  style: TextStyle(color: Colors.red),
                ),
              );
            },
          ),
        ),
      );
    }

    // Fallback for other types or if something went wrong
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 60),
          const SizedBox(height: 16),
          Text(
            // Show extension if available, otherwise content type
            'Cannot display file type: ${_fileExtension ?? _contentType ?? 'Unknown'}',
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Save File'),
            onPressed:
                _isLoading || _fileBytes == null
                    ? null
                    : () => _onDownload(context),
          ),
        ],
      ),
    );
  }
}
