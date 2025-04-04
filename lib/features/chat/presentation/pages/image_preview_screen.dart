import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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

class _ImagePreviewScreenState extends ConsumerState<ImagePreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Set system UI overlay style to ensure full immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize animation controller for fade-in effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    // Restore system UI when leaving the screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _animationController.dispose();
    super.dispose();
  }

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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        // Use black background for a more typical image preview look
        backgroundColor: Colors.black,
        // Don't show app bar
        appBar: null,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Image preview (centered with proper background)
            Container(
              color: Colors.black,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        spreadRadius: 5,
                        blurRadius: 7,
                      ),
                    ],
                  ),
                  child: _buildImagePreview(),
                ),
              ),
            ),

            // Custom top bar with title
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  bottom: 16,
                  left: 8,
                  right: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Preview Image', // TODO: Add to localization
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom actions with improved styling
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  top: 24,
                  left: 20,
                  right: 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Cancel button with improved styling
                    Container(
                      width: size.width * 0.4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextButton.icon(
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: Text(
                          l10n.commonCancel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ),

                    // Send button with improved styling
                    Container(
                      width: size.width * 0.4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextButton.icon(
                        icon:
                            _isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                                : const Icon(Icons.send, color: Colors.white),
                        label: Text(
                          l10n.chatSendMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: _isLoading ? null : _sendImage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
                return Container(
                  width: double.infinity,
                  height: 300,
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                print('Error loading image preview: ${snapshot.error}');
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Error loading image: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'No image data available',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                );
              }

              // Use Image.memory for web with the bytes from XFile
              return Hero(
                tag: 'preview_image',
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('Error rendering image: $error');
                    print(stackTrace);
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Unable to preview image: $error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        } else {
          print(
            'Unsupported image format for web: ${widget.imageFile.runtimeType}',
          );
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Unsupported image format',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
      } else {
        // Mobile implementation
        if (widget.imageFile is XFile) {
          return Hero(
            tag: 'preview_image',
            child: Image.file(
              File((widget.imageFile as XFile).path),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Error displaying image file: $error');
                print(stackTrace);
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Error displaying image: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              },
            ),
          );
        } else if (widget.imageFile is File) {
          return Hero(
            tag: 'preview_image',
            child: Image.file(
              widget.imageFile as File,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print('Error displaying image file: $error');
                print(stackTrace);
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Error displaying image: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                );
              },
            ),
          );
        } else {
          print(
            'Unsupported image format for mobile: ${widget.imageFile.runtimeType}',
          );
          return Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Unsupported image format: ${widget.imageFile.runtimeType}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      print('Exception in _buildImagePreview: $e');
      print(stackTrace);
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Error previewing image: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
  }
}
