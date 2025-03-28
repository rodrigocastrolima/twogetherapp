import 'dart:io';
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
    _setUserActiveInConversation(false);

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
                              ? _buildImageContent(message.content)
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
        maxHeight: 200,
      ),
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
          errorWidget:
              (context, url, error) =>
                  const Icon(Icons.error, color: CupertinoColors.systemRed),
          fit: BoxFit.cover,
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
}
