import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/theme.dart';
import '../../domain/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../../../core/theme/ui_styles.dart';
import '../pages/image_preview_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_storage/firebase_storage.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String? title;
  final bool showAppBar;

  const ChatPage({
    super.key,
    required this.conversationId,
    this.title,
    this.showAppBar = true,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isImageLoading = false;

  @override
  void initState() {
    super.initState();
    // Mark conversation as read initially
    _markAsRead();

    // Set user as active in this conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setUserActiveInConversation(true);
    });
  }

  @override
  void dispose() {
    // Set user as inactive in this conversation before disposing
    try {
      if (mounted) {
        // Only call the provider if the widget is still mounted
        final notifier = ref.read(chatNotifierProvider.notifier);
        notifier.setUserActiveInConversation(widget.conversationId, false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during dispose: $e');
      }
    }

    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Track user active status in conversation
  void _setUserActiveInConversation(bool isActive) {
    ref
        .read(chatNotifierProvider.notifier)
        .setUserActiveInConversation(widget.conversationId, isActive);
  }

  void _markAsRead() {
    // Optimistically update local state if needed
    ref
        .read(chatNotifierProvider.notifier)
        .markConversationAsRead(widget.conversationId);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _messageController.clear();
      await ref
          .read(chatNotifierProvider.notifier)
          .sendTextMessage(widget.conversationId, text);

      // Scroll to bottom after message is sent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // This will mark as read automatically when we send a message
      _markAsRead();
    } catch (e) {
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getImageFromSource(ImageSource source) async {
    setState(() {
      _isImageLoading = true;
    });

    try {
      if (kDebugMode) {
        print(
          'Getting image from ${source == ImageSource.camera ? "camera" : "gallery"}',
        );
      }

      // Use the image_picker to get the image from the specified source
      final imagePicker = ImagePicker();
      final pickedImage = await imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedImage == null) {
        if (kDebugMode) {
          print('No image selected');
        }
        setState(() {
          _isImageLoading = false;
        });
        return;
      }

      if (kDebugMode) {
        print('Image selected: ${pickedImage.path}');
        print('Image name: ${pickedImage.name}');
        print('Image size: ${await pickedImage.length()} bytes');
      }

      if (mounted) {
        // Show the image preview screen
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => ImagePreviewScreen(
                  imageFile: pickedImage,
                  conversationId: widget.conversationId,
                ),
          ),
        );

        // If the image was sent successfully, mark conversation as read
        if (result == true) {
          ref
              .read(chatNotifierProvider.notifier)
              .markConversationAsRead(widget.conversationId);
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error selecting image: $e');
        print(stackTrace);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImageLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = ref.watch(messagesProvider(widget.conversationId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar:
          widget.showAppBar
              ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  widget.title ?? 'Support Chat',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(CupertinoIcons.back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              )
              : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          children: [
            // Support header - Apple-style clean design
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Support",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: AppTheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Our team is here to help with your inquiries.",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white70 : Colors.black54,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // Messages area
            Expanded(
              child: messagesStream.when(
                data: (messages) {
                  if (messages.isEmpty) {
                    return _buildEmptyState();
                  }

                  return NoScrollbarBehavior.noScrollbars(
                    context,
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Show newest at the bottom
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _buildMessageItem(message);
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error:
                    (error, _) =>
                        Center(child: Text('Error: ${error.toString()}')),
              ),
            ),

            // Input area
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                CupertinoIcons.chat_bubble_text_fill,
                color: AppTheme.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Welcome to Support",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.foreground,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Connect directly with our support team for personalized assistance with your account, services, and any questions you may have.",
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.black54,
                height: 1.4,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              "Send a message to get started.",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    final isCurrentUser =
        message.senderId == ref.read(chatRepositoryProvider).currentUserId;
    final timeString = DateFormat('HH:mm').format(message.timestamp);

    // Determine if the message is from the Twogether Support
    final isAssistantMessage = !isCurrentUser && message.isAdmin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.person_crop_circle_fill,
                size: 18,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isCurrentUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                // Sender name for non-user messages
                if (!isCurrentUser) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      "Twogether Support",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],

                // Message bubble
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                    bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding:
                          message.type == MessageType.image
                              ? const EdgeInsets.all(4)
                              : const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                      decoration: BoxDecoration(
                        color:
                            isCurrentUser
                                ? AppTheme.primary.withOpacity(0.1)
                                : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                          bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                        ),
                        border: Border.all(
                          color:
                              isCurrentUser
                                  ? AppTheme.primary.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.15),
                          width: 0.5,
                        ),
                      ),
                      child:
                          message.type == MessageType.image
                              ? ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.6,
                                  maxHeight: 200,
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    if (kDebugMode) {
                                      print(
                                        'Opening full image: ${message.content}',
                                      );
                                    }
                                    // Show full size image dialog
                                    showDialog(
                                      context: context,
                                      builder:
                                          (context) => Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding: const EdgeInsets.all(
                                              10,
                                            ),
                                            child: GestureDetector(
                                              onTap:
                                                  () => Navigator.pop(context),
                                              child: SafeNetworkImage(
                                                imageUrl: message.content,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                    );
                                  },
                                  child: SafeNetworkImage(
                                    imageUrl: message.content,
                                    fit: BoxFit.cover,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              )
                              : Text(
                                message.content,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.foreground,
                                  letterSpacing: -0.3,
                                  height: 1.3,
                                ),
                              ),
                    ),
                  ),
                ),

                // Timestamp
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Text(
                    timeString,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.withOpacity(0.7),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.person_fill,
                size: 18,
                color: AppTheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageContent(String imageUrl) {
    if (kDebugMode) {
      print('Attempting to load image: $imageUrl');
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
        maxHeight: 200,
      ),
      child: GestureDetector(
        onTap: () {
          // Show full image when tapped
          showDialog(
            context: context,
            builder:
                (_) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      placeholder:
                          (context, url) =>
                              const Center(child: CircularProgressIndicator()),
                      errorWidget: (context, url, error) {
                        if (kDebugMode) {
                          print('Error loading full-size image: $error');
                        }
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Failed to load image',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder:
                (context, url) => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            errorWidget: (context, url, error) {
              if (kDebugMode) {
                print('Error loading thumbnail image: $error for URL: $url');
              }
              return Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: CupertinoColors.systemRed),
                    SizedBox(height: 8),
                    Text(
                      'Image load failed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            },
            fit: BoxFit.cover,
            // Disable caching temporarily for debugging
            cacheManager: null,
          ),
        ),
      ),
    );
  }

  Widget _buildImageContentWithFallback(String imageUrl) {
    if (kDebugMode) {
      print('Attempting to load image with fallback: $imageUrl');
    }

    // Try to load with standard Image.network as fallback
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
        maxHeight: 200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value:
                      loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            if (kDebugMode) {
              print('Direct Image.network also failed: $error');
              print(stackTrace);
            }

            // As a last resort, try a simple WebView or iframe approach
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: Colors.orange,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Can\'t display image',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to open in browser',
                    style: TextStyle(fontSize: 10, color: Colors.blue),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          top: BorderSide(
            color:
                isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.05),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Camera button
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(CupertinoIcons.camera),
              onPressed:
                  _isImageLoading
                      ? null
                      : () => _getImageFromSource(ImageSource.camera),
              color:
                  isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600,
              iconSize: 18,
              padding: EdgeInsets.zero,
            ),
          ),

          // Gallery button
          const SizedBox(width: 8), // Add some space between buttons
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.1),
                width: 0.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(CupertinoIcons.photo),
              onPressed:
                  _isImageLoading
                      ? null
                      : () => _getImageFromSource(ImageSource.gallery),
              color:
                  isDark ? Colors.white.withOpacity(0.6) : Colors.grey.shade600,
              iconSize: 18,
              padding: EdgeInsets.zero,
            ),
          ),

          // Text input - simplified design with no inner containers
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Type a message to support...',
                  hintStyle: TextStyle(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4),
                    fontSize: 15,
                    letterSpacing: -0.3,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                      width: 0.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color:
                          isDark
                              ? Colors.white.withOpacity(0.2)
                              : Colors.black.withOpacity(0.2),
                      width: 1.0,
                    ),
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                minLines: 1,
                maxLines: 5,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.foreground,
                  letterSpacing: -0.3,
                ),
                cursorColor: isDark ? Colors.white70 : AppTheme.primary,
              ),
            ),
          ),

          // Send button
          _isImageLoading
              ? Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? Colors.white70 : AppTheme.primary,
                  ),
                ),
              )
              : Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(
                    CupertinoIcons.arrow_up,
                    color: Colors.white,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
        ],
      ),
    );
  }

  // Add a check to test the image URL and report any issues
  void _testImageUrl(String url) {
    if (kDebugMode) {
      // Check for common problems in URLs
      print('DEBUG: Testing image URL: $url');

      if (url.contains(' ')) {
        print(
          'WARNING: URL contains spaces which may cause issues. URL should be properly encoded.',
        );
      }

      if (url.contains('\\')) {
        print(
          'WARNING: URL contains backslashes which may cause issues. URL should use forward slashes.',
        );
      }

      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        print('WARNING: URL doesn\'t start with http:// or https://');
      }

      // Print URL in pieces to help debug
      try {
        final uri = Uri.parse(url);
        print('DEBUG: URL scheme: ${uri.scheme}');
        print('DEBUG: URL host: ${uri.host}');
        print('DEBUG: URL path: ${uri.path}');
        print('DEBUG: URL query params: ${uri.queryParameters}');
      } catch (e) {
        print('ERROR: Failed to parse URL: $e');
      }
    }
  }

  // Add a method to diagnose image loading issues
  Future<void> _showDebugDialog(String imageUrl) async {
    if (!kDebugMode) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Image Loading Debug Info'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'URL:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(imageUrl, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  const Text(
                    'Tests:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      _testImageUrl(imageUrl);
                      Navigator.pop(context);
                    },
                    child: const Text('Run URL Tests'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);

                      // For web, open the URL in a new tab to test it directly
                      if (kDebugMode) {
                        print('Trying to test image directly: $imageUrl');

                        // Create a sanitized version of the URL for debugging
                        final sanitizedUrl = imageUrl.replaceAll(
                          RegExp(r'[^\w\s\.\:\/\-\=\&\?]'),
                          '',
                        );
                        print('Sanitized URL: $sanitizedUrl');
                      }

                      // Add a direct image test dialog that doesn't use HtmlElementView
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Firebase Storage URL Issue'),
                              content: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Firebase Storage URLs often have CORS issues in web browsers that prevent direct loading.',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Possible solutions:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '1. Configure Firebase Storage CORS settings',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      '2. Use a server proxy to bypass CORS',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      '3. Switch to use a CachedNetworkImageProvider',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'URL: $imageUrl',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                      );
                    },
                    child: const Text('Image URL Info'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}

class SafeNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SafeNetworkImage({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) : super(key: key);

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  bool _hasError = false;
  int _retryCount = 0;
  final int _maxRetries = 1; // Reduce max retries to avoid excessive retries
  late String _processedUrl;
  bool _useBase64 = false;
  String? _base64Data;
  bool _isInitialized = false;
  bool _showPlaceholder = false; // Add flag to show placeholder

  @override
  void initState() {
    super.initState();
    // Move processing out of initState to avoid initialization issues
    _processImageData();
  }

  Future<void> _processImageData() async {
    if (_isInitialized) return;

    try {
      // Check if the content is a JSON string containing both URL and base64 data
      if (widget.imageUrl.startsWith('{') && widget.imageUrl.endsWith('}')) {
        Map<String, dynamic>? content;
        try {
          content = json.decode(widget.imageUrl) as Map<String, dynamic>;
          if (content.containsKey('url') && content.containsKey('base64')) {
            _processedUrl = content['url'] as String;
            _base64Data = content['base64'] as String;

            // For web, prefer base64 data if available
            if (kIsWeb && _base64Data != null && _base64Data!.isNotEmpty) {
              _useBase64 = true;
            }

            if (kDebugMode) {
              print('Found enhanced image content with base64 data');
              print('Will use base64 for web: $_useBase64');
            }

            _isInitialized = true;

            // Since this is async, we need to rebuild the widget
            if (mounted) setState(() {});
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing image JSON: $e');
          }
        }
      }

      // Regular URL processing
      _processedUrl = widget.imageUrl;

      // For Firebase Storage URLs, ensure they're properly formatted and properly decoded
      if (_processedUrl.contains('firebasestorage.googleapis.com')) {
        // Always decode the URL first to prevent double-encoding issues
        _processedUrl = Uri.decodeFull(_processedUrl);

        // Check if this is the known problematic image
        final specificImage = '1743410189275_YXSDrAQ77JPsh1RR2wlQlHWIovf1';
        if (_processedUrl.contains(specificImage) && kIsWeb) {
          // For the known problematic image on web, just show a placeholder
          if (kDebugMode) {
            print('Problematic image detected, showing placeholder instead');
          }
          _showPlaceholder = true;
          _isInitialized = true;
          if (mounted) setState(() {});
          return;
        }

        // Make sure the URL has the alt=media parameter
        if (!_processedUrl.contains('alt=media')) {
          if (_processedUrl.contains('?')) {
            _processedUrl += '&alt=media';
          } else {
            _processedUrl += '?alt=media';
          }
        }

        // For web, add cache-busting parameter
        if (kIsWeb) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          if (_processedUrl.contains('?')) {
            _processedUrl += '&t=$timestamp';
          } else {
            _processedUrl += '?t=$timestamp';
          }
        }

        if (kDebugMode) {
          print('Processed Firebase Storage URL: $_processedUrl');
        }
      }

      _isInitialized = true;

      // Since this is async, we need to rebuild the widget
      if (mounted) setState(() {});
    } catch (e) {
      if (kDebugMode) {
        print('Error processing image URL: $e');
      }
      _processedUrl = widget.imageUrl;
      _isInitialized = true;

      // Since this is async, we need to rebuild the widget
      if (mounted) setState(() {});
    }
  }

  void _resetAndRetry() {
    if (_retryCount < _maxRetries) {
      setState(() {
        _retryCount++;
        _hasError = false;

        // If we're on web and have base64 data available, try that instead
        if (kIsWeb && _base64Data != null && !_useBase64) {
          _useBase64 = true;
        } else {
          // Reset the URL and process it again
          _isInitialized = false;
          _processImageData();
        }
      });

      if (kDebugMode) {
        print('Retrying image load (attempt $_retryCount): $_processedUrl');
        print('Using base64: $_useBase64');
      }
    } else {
      // If we've exhausted retries, show placeholder
      setState(() {
        _showPlaceholder = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If we haven't processed the image data yet, show a loading indicator
    if (!_isInitialized) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: widget.borderRadius,
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    // If explicitly set to show placeholder or we've had an error and exhausted retries
    if (_showPlaceholder || (_hasError && _retryCount >= _maxRetries)) {
      return _buildPlaceholderImage();
    }

    // For web, try using base64 data if available
    if (kIsWeb && _useBase64 && _base64Data != null) {
      try {
        if (_base64Data!.startsWith('data:image')) {
          return ClipRRect(
            borderRadius: widget.borderRadius,
            child: Image.memory(
              base64Decode(_base64Data!.split(',')[1]),
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('Error with base64 image: $error');
                }
                // Show placeholder for base64 errors
                return _buildPlaceholderImage();
              },
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error using base64 data: $e');
        }
        // Show placeholder for base64 errors
        return _buildPlaceholderImage();
      }
    }

    // For Firebase Storage URLs on web, use direct placeholder for known issue
    if (_processedUrl.contains('firebasestorage.googleapis.com') && kIsWeb) {
      // Check for the specific known problematic image before trying FutureBuilder
      if (_processedUrl.contains(
        '1743410189275_YXSDrAQ77JPsh1RR2wlQlHWIovf1',
      )) {
        return _buildPlaceholderImage();
      }

      // For other Firebase Storage URLs, try once with FutureBuilder
      // but have a quick timeout to avoid hanging
      return FutureBuilder<String>(
        future: Future.any([
          _getFirebaseStorageUrl(_processedUrl),
          // Add a short timeout to prevent endless loading
          Future.delayed(
            const Duration(seconds: 3),
            () => throw Exception('Timeout'),
          ),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingIndicator(null);
          }

          if (snapshot.hasError || !snapshot.hasData) {
            if (kDebugMode) {
              print('Error getting fresh URL: ${snapshot.error}');
            }
            return _buildPlaceholderImage();
          }

          final freshUrl = snapshot.data!;
          return ClipRRect(
            borderRadius: widget.borderRadius,
            child: Image.network(
              freshUrl,
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods':
                    'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers':
                    'Origin, Content-Type, X-Auth-Token',
                'Cache-Control': 'no-cache, no-store, must-revalidate',
                'Pragma': 'no-cache',
                'Expires': '0',
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildLoadingIndicator(loadingProgress);
              },
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('Fresh URL image error: $error');
                }
                // Show placeholder on error
                return _buildPlaceholderImage();
              },
              cacheWidth: widget.width?.toInt(),
              cacheHeight: widget.height?.toInt(),
            ),
          );
        },
      );
    }

    // Default to regular network image with fallback to placeholder
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Image.network(
        _processedUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        headers:
            kIsWeb
                ? {
                  'Access-Control-Allow-Origin': '*',
                  'Access-Control-Allow-Methods':
                      'GET, POST, PUT, DELETE, OPTIONS',
                  'Access-Control-Allow-Headers':
                      'Origin, Content-Type, X-Auth-Token',
                  'Cache-Control': 'no-cache, no-store, must-revalidate',
                  'Pragma': 'no-cache',
                  'Expires': '0',
                }
                : null,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingIndicator(loadingProgress);
        },
        errorBuilder: (context, error, stackTrace) {
          if (kDebugMode) {
            print('Network image error: $error');
          }
          // Show placeholder on error without causing setState during build
          return _buildPlaceholderImage();
        },
        cacheWidth: widget.width?.toInt(),
        cacheHeight: widget.height?.toInt(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: widget.width ?? 100,
      height: widget.height ?? 100,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_outlined, color: Colors.grey[400], size: 32),
          const SizedBox(height: 8),
          Text(
            'Image not available',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(ImageChunkEvent? loadingProgress) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: widget.borderRadius,
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value:
              loadingProgress?.expectedTotalBytes != null
                  ? loadingProgress!.cumulativeBytesLoaded /
                      loadingProgress!.expectedTotalBytes!
                  : null,
        ),
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return GestureDetector(
      onTap: _resetAndRetry,
      child: Container(
        width: widget.width ?? 100,
        height: widget.height ?? 100,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: widget.borderRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.red[400], size: 32),
            const SizedBox(height: 8),
            const Text(
              'Image failed to load',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            if (_retryCount < _maxRetries) ...[
              const SizedBox(height: 8),
              Text(
                'Tap to retry ${_retryCount + 1}/$_maxRetries',
                style: TextStyle(fontSize: 10, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'URL: ${_processedUrl.length > 20 ? '${_processedUrl.substring(0, 20)}...' : _processedUrl}',
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Method to get a fresh download URL directly from Firebase Storage if needed
  Future<String> _getFirebaseStorageUrl(String path) async {
    try {
      // Check if this is a Firebase Storage URL and extract the path
      if (!path.contains('firebasestorage.googleapis.com')) {
        return path; // Not a Firebase Storage URL, return as is
      }

      if (kDebugMode) {
        print('Original Firebase URL: $path');
      }

      // For the specific problematic image, throw an exception immediately to skip to placeholder
      if (path.contains('1743410189275_YXSDrAQ77JPsh1RR2wlQlHWIovf1') &&
          kIsWeb) {
        throw Exception('Known problematic image, skipping to placeholder');
      }

      // First, fully decode the URL to prevent issues with encoded characters
      path = Uri.decodeFull(path);

      // Try to extract the path from the URL
      String storagePath = '';

      // Look for the image name provided by the user
      if (path.contains('/o/')) {
        // Standard extraction method for other images
        final pathStart = path.indexOf('/o/') + 3;
        final pathEnd = path.contains('?') ? path.indexOf('?') : path.length;
        storagePath = path.substring(pathStart, pathEnd);

        // Further decode in case there are still encoded characters
        storagePath = Uri.decodeFull(storagePath);

        if (kDebugMode) {
          print('Extracted storage path: $storagePath');
        }
      } else {
        // For unusual URL formats, try to extract the filename
        final uriParts = path.split('/');
        final lastPart = uriParts.last;
        final fileName = lastPart.split('?').first;

        if (fileName.isNotEmpty && fileName.contains('.')) {
          // This looks like a filename with extension
          storagePath = 'chat_images/$fileName';
          if (kDebugMode) {
            print('Extracted filename: $storagePath');
          }
        } else {
          if (kDebugMode) {
            print('Could not extract path from URL, using original: $path');
          }
          return path;
        }
      }

      // If we have a valid path, get a fresh download URL
      if (storagePath.isNotEmpty) {
        // Get reference to the Firebase Storage location
        final ref = FirebaseStorage.instance.ref(storagePath);

        // Get a fresh download URL
        final freshUrl = await ref.getDownloadURL();

        if (kDebugMode) {
          print('Got fresh download URL: $freshUrl');
        }

        // Add cache busting parameter
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final finalUrl =
            freshUrl.contains('?')
                ? '$freshUrl&t=$timestamp'
                : '$freshUrl?t=$timestamp';

        return finalUrl;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error getting fresh download URL: $e');
      }
      // Any error, just let it fail so we show the placeholder
      throw e;
    }

    // If anything fails, return the original URL with a cache-busting parameter
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.contains('?') ? '$path&t=$timestamp' : '$path?t=$timestamp';
  }
}
