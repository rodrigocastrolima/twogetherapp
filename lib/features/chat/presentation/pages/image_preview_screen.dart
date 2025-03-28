import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/ui_styles.dart';
import '../providers/chat_provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class ImagePreviewScreen extends ConsumerStatefulWidget {
  final dynamic imageFile; // Can be XFile, File, etc.
  final String conversationId;

  const ImagePreviewScreen({
    Key? key,
    required this.imageFile,
    required this.conversationId,
  }) : super(key: key);

  @override
  ConsumerState<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends ConsumerState<ImagePreviewScreen> {
  bool _isLoading = false;

  Future<void> _sendImage() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (kDebugMode) {
        print('Starting image sending process');
        print('Image file type: ${widget.imageFile.runtimeType}');
        if (widget.imageFile is XFile) {
          print('XFile path: ${(widget.imageFile as XFile).path}');
          print('XFile name: ${(widget.imageFile as XFile).name}');
          print(
            'XFile size: ${await (widget.imageFile as XFile).length()} bytes',
          );
        }
      }

      // For web uploads, we need a longer timeout
      final timeout =
          kIsWeb ? const Duration(minutes: 2) : const Duration(seconds: 45);

      // Send the image using the ChatNotifier with timeout
      await Future.any([
        ref
            .read(chatNotifierProvider.notifier)
            .sendImageMessage(widget.conversationId, widget.imageFile),
        Future.delayed(timeout, () {
          throw Exception(
            "Upload timed out after ${timeout.inSeconds} seconds. Please check your internet connection and try again.",
          );
        }),
      ]);

      if (kDebugMode) {
        print('Successfully sent image message');
      }

      if (mounted) {
        // Pop back to chat screen after successful upload
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error in _sendImage method: $e');
        print(stackTrace);
      }

      // Handle specific Firebase Storage errors
      String errorMessage = 'Error sending image: ${e.toString()}';

      if (e.toString().contains('storage/unauthorized')) {
        errorMessage =
            'Unauthorized to upload images. Please check your login credentials.';
      } else if (e.toString().contains('storage/quota-exceeded')) {
        errorMessage = 'Storage quota exceeded. Please contact support.';
      } else if (e.toString().contains('storage/canceled')) {
        errorMessage = 'Image upload was canceled.';
      } else if (e.toString().contains('storage/unknown')) {
        errorMessage =
            'Unknown error occurred during upload. Please try again.';
      } else if (e.toString().contains('storage/retry-limit-exceeded')) {
        errorMessage =
            'Network error. Please check your internet connection and try again.';
      } else if (e.toString().contains('timed out')) {
        errorMessage =
            'Upload timed out. Please check your internet connection and try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
        // Don't pop - let user try again
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        title: Text(
          'Preview Image',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Image preview
          Center(child: _buildImagePreview()),

          // Bottom actions
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  TextButton.icon(
                    icon: Icon(Icons.cancel, color: Colors.white70),
                    label: Text(
                      "Cancel",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: Colors.white.withOpacity(0.1),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),

                  // Send button
                  TextButton.icon(
                    icon:
                        _isLoading
                            ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                            : Icon(Icons.send, color: Colors.white),
                    label: Text(
                      "Send",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      backgroundColor: AppTheme.primary,
                    ),
                    onPressed: _isLoading ? null : _sendImage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    try {
      if (kIsWeb) {
        // Web implementation
        if (widget.imageFile is XFile) {
          // For web, we need to handle XFile differently
          return FutureBuilder<Uint8List>(
            future: (widget.imageFile as XFile).readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                print('Error loading image preview: ${snapshot.error}');
                return Center(
                  child: Text(
                    'Error loading image: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No image data available',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              // Use Image.memory for web with the bytes from XFile
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  print('Error rendering image: $error');
                  print(stackTrace);
                  return Center(
                    child: Text(
                      'Unable to preview image: $error',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                },
              );
            },
          );
        } else {
          print(
            'Unsupported image format for web: ${widget.imageFile.runtimeType}',
          );
          return const Center(
            child: Text(
              'Unsupported image format',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
      } else {
        // Mobile implementation
        if (widget.imageFile is XFile) {
          return Image.file(
            File((widget.imageFile as XFile).path),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('Error displaying image file: $error');
              print(stackTrace);
              return Center(
                child: Text(
                  'Error displaying image: $error',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            },
          );
        } else if (widget.imageFile is File) {
          return Image.file(
            widget.imageFile as File,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print('Error displaying image file: $error');
              print(stackTrace);
              return Center(
                child: Text(
                  'Error displaying image: $error',
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            },
          );
        } else {
          print(
            'Unsupported image format for mobile: ${widget.imageFile.runtimeType}',
          );
          return Center(
            child: Text(
              'Unsupported image format: ${widget.imageFile.runtimeType}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Exception in _buildImagePreview: $e');
      print(stackTrace);
      return Center(
        child: Text(
          'Error previewing image: $e',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
  }
}
