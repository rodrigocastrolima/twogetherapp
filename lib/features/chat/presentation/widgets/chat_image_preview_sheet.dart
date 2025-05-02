import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../../../../core/theme/theme.dart';
import '../providers/chat_provider.dart';

class ChatImagePreviewSheet extends ConsumerStatefulWidget {
  final dynamic imageFile; // Can be XFile or File
  final String conversationId;

  const ChatImagePreviewSheet({
    Key? key,
    required this.imageFile,
    required this.conversationId,
  }) : super(key: key);

  @override
  ConsumerState<ChatImagePreviewSheet> createState() =>
      _ChatImagePreviewSheetState();
}

class _ChatImagePreviewSheetState extends ConsumerState<ChatImagePreviewSheet> {
  bool _isLoading = false;

  Future<void> _handleSendImage() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    // Keep track of the original context before async gap
    final currentContext = context;

    try {
      if (kDebugMode) {
        print('Starting image sending process from bottom sheet');
        print('Image file type: ${widget.imageFile.runtimeType}');
      }

      final timeout =
          kIsWeb ? const Duration(minutes: 2) : const Duration(seconds: 45);

      await Future.any([
        ref
            .read(chatNotifierProvider.notifier)
            .sendImageMessage(widget.conversationId, widget.imageFile),
        Future.delayed(timeout, () {
          throw TimeoutException(
            "Upload timed out after ${timeout.inSeconds} seconds.",
          );
        }),
      ]);

      if (kDebugMode) {
        print('Successfully sent image message from bottom sheet');
      }

      // Close the bottom sheet on success
      if (mounted) {
        Navigator.pop(currentContext, true); // Indicate success
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('Error sending image: $e');
      }
      if (mounted) {
        // Show timeout error
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text('Tempo limite de upload excedido.'),
            backgroundColor: Theme.of(currentContext).colorScheme.error,
          ),
        );
        // Close the bottom sheet even on timeout
        Navigator.pop(currentContext, false);
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error in _handleSendImage: $e');
        print(stackTrace);
      }

      // Generic error message (customize as needed)
      final errorMessage = 'Erro ao enviar imagem: ${e.toString()}';

      if (mounted) {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(currentContext).colorScheme.error,
          ),
        );
        // Close the bottom sheet on error
        Navigator.pop(currentContext, false);
      }
    } finally {
      // Ensure loading state is reset even if context is gone
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final l10n = AppLocalizations.of(context)!; // Remove l10n init
    // final size = MediaQuery.of(context).size; // No longer needed for sizing

    // Use a Scaffold for structure within the overlay route
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(
        0.85,
      ), // Dark semi-transparent background
      body: Stack(
        children: [
          // --- Image Preview Area (Centered and Expanded) ---
          Center(
            child: Padding(
              // Add padding around the image itself if needed
              padding: const EdgeInsets.all(32.0),
              child: SingleChildScrollView(
                child: _buildImagePreviewWidget(context),
              ),
            ),
          ),

          // --- Close Button (Top Left) ---
          Positioned(
            top:
                MediaQuery.of(context).padding.top +
                10, // Adjust position below status bar
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              tooltip: 'Cancelar',
              onPressed: () => Navigator.pop(context, false),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.3),
              ),
            ),
          ),

          // --- Send Button (Bottom Right) ---
          Positioned(
            bottom:
                MediaQuery.of(context).padding.bottom +
                20, // Adjust position above nav bar/safe area
            right: 20,
            child: FloatingActionButton(
              tooltip: 'Enviar uma mensagem',
              backgroundColor: theme.colorScheme.primary,
              onPressed: _isLoading ? null : _handleSendImage,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Adapted from ImagePreviewScreen._buildImagePreview
  Widget _buildImagePreviewWidget(BuildContext context) {
    try {
      if (kIsWeb) {
        if (widget.imageFile is XFile) {
          return FutureBuilder<Uint8List>(
            future: (widget.imageFile as XFile).readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                print('Error loading web preview: ${snapshot.error}');
                return _buildPreviewErrorWidget(
                  'Erro ao carregar pré-visualização',
                );
              }
              return Image.memory(snapshot.data!, fit: BoxFit.contain);
            },
          );
        } else {
          print(
            'Unsupported web image file type: ${widget.imageFile.runtimeType}',
          );
          return _buildPreviewErrorWidget('Tipo de ficheiro não suportado');
        }
      } else {
        // Mobile
        if (widget.imageFile is XFile) {
          return Image.file(
            File((widget.imageFile as XFile).path),
            fit: BoxFit.contain,
          );
        } else if (widget.imageFile is File) {
          return Image.file(widget.imageFile as File, fit: BoxFit.contain);
        } else {
          print(
            'Unsupported mobile image file type: ${widget.imageFile.runtimeType}',
          );
          return _buildPreviewErrorWidget('Tipo de ficheiro não suportado');
        }
      }
    } catch (e, stackTrace) {
      print('Exception in _buildImagePreviewWidget: $e\n$stackTrace');
      return _buildPreviewErrorWidget('Erro ao exibir pré-visualização');
    }
  }

  Widget _buildPreviewErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
        textAlign: TextAlign.center,
      ),
    );
  }
}
