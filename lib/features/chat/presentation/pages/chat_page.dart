import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../domain/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../../../core/theme/ui_styles.dart';
import '../widgets/chat_image_preview_sheet.dart';
import '../widgets/chat_file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';

// Add extension to ChatMessage for cleaner code
extension ChatMessageExtension on ChatMessage {
  // Static variable to hold the current user ID
  static String? currentUserId;

  // Use the actual user ID from the chat repository
  bool get isFromUser => senderId == ChatMessageExtension.currentUserId;
  bool get isFromAdmin => isAdmin == true;
  bool get isImage => type == MessageType.image;
  bool get isFile => type == MessageType.file;
}

class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String? title;
  final bool showAppBar;
  final bool isAdminView;

  const ChatPage({
    super.key,
    required this.conversationId,
    this.title,
    this.showAppBar = true,
    this.isAdminView = false,
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
  bool _hasText = false; // Add this to track whether there's text in the input
  Timer? _debounceTimer; // Add debounce timer to prevent too many updates
  late final ChatNotifier _chatNotifier; // <-- ADD member variable

  @override
  void initState() {
    super.initState();
    _chatNotifier = ref.read(
      chatNotifierProvider.notifier,
    ); // <-- INITIALIZE here
    // Mark conversation as read initially
    _markAsRead();

    // Add listener to text controller to update _hasText state
    _messageController.addListener(_updateHasText);

    // Set user as active in this conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use the stored notifier instance
      _chatNotifier.setUserActiveInConversation(widget.conversationId, true);
      // _setUserActiveInConversation(true); // Keep or remove helper? Let's keep for now
    });
  }

  @override
  void dispose() {
    if (kDebugMode) {
      print('--- ChatPage dispose START ---');
    }
    // Remove listener from text controller
    _messageController.removeListener(_updateHasText);

    // Cancel the debounce timer if it exists
    _debounceTimer?.cancel();

    // Set user as inactive in this conversation before disposing
    try {
      // Use the stored notifier instance directly
      if (kDebugMode) {
        print('--- ChatPage dispose: Calling setUserActive(false) ---');
      }
      _chatNotifier.setUserActiveInConversation(widget.conversationId, false);
      /* --- REMOVE OLD LOGIC ---
      if (mounted) {
        print('--- ChatPage dispose: Calling setUserActive(false) ---');
        // final notifier = ref.read(chatNotifierProvider.notifier); // <-- Don't read here
        _chatNotifier.setUserActiveInConversation(widget.conversationId, false);
      } else {
          print('--- ChatPage dispose: Widget not mounted! ---'); 
      }
      */
    } catch (e) {
      if (kDebugMode) {
        print('--- ChatPage dispose: ERROR calling setUserActive: $e ---');
      }
    }

    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    if (kDebugMode) {
      print('--- ChatPage dispose END ---');
    }
    super.dispose();
  }

  void _markAsRead() {
    // Use the stored notifier
    _chatNotifier.markConversationAsRead(widget.conversationId);
    // ref
    //     .read(chatNotifierProvider.notifier)
    //     .markConversationAsRead(widget.conversationId);
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
          SnackBar(content: Text('Erro ao enviar mensagem: ${e.toString()}')),
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
        // Show the image preview as a semi-transparent overlay route
        final result = await Navigator.of(context, rootNavigator: true).push(
          PageRouteBuilder(
            opaque: false, // Makes the route transparent
            fullscreenDialog: true,
            transitionDuration: const Duration(
              milliseconds: 200,
            ), // Match old duration
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    ChatImagePreviewSheet(
                      imageFile: pickedImage,
                      conversationId: widget.conversationId,
                    ),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              // Simple Fade transition
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );

        /* // REMOVE Old showModalBottomSheet logic
        final result = await showModalBottomSheet(
          context: context,
          isScrollControlled: true, // Allows sheet to be taller
          backgroundColor: Colors.transparent, // Make background transparent
          builder: (sheetContext) => ChatImagePreviewSheet(
             imageFile: pickedImage,
             conversationId: widget.conversationId,
          ),
        );
        */

        // If the image was sent successfully (result is true), mark as read & scroll
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
            content: Text('Erro ao selecionar imagem: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
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
    final theme = Theme.of(context);

    // Update the extension placeholder with the actual current user ID
    final currentUserId = ref.read(chatRepositoryProvider).currentUserId;
    ChatMessageExtension.currentUserId = currentUserId;

    // Debug logging when messages stream changes
    if (kDebugMode && messagesStream is AsyncLoading) {
      if (kDebugMode) {
        print('DEBUG: Messages stream loading for ${widget.conversationId}');
      }
    } else if (kDebugMode && messagesStream is AsyncError) {
      if (kDebugMode) {
        print(
          'DEBUG: Messages stream error: ${(messagesStream as AsyncError).error}',
        );
      }
    } else if (kDebugMode && messagesStream is AsyncData) {
      if (kDebugMode) {
        print(
          'DEBUG: Messages loaded: ${(messagesStream as AsyncData<List<ChatMessage>>).value.length}',
        );
      }
    }

    // Check if support is online (between 9am and 6pm)
    final isOnline = _isBusinessHours();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar:
          widget.showAppBar
              ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User avatar with circle
                    CircleAvatar(
                      backgroundColor:
                          theme.brightness == Brightness.dark
                              ? theme.colorScheme.surface
                              : theme.colorScheme.primary.withOpacity(0.8),
                      radius: 20,
                      child: Text(
                        (widget.title?.isNotEmpty == true)
                            ? widget.title![0].toUpperCase()
                            : 'S', // Fallback initial
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color:
                              theme.brightness == Brightness.dark
                                  ? theme.colorScheme.onSurface
                                  : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // User name with online indicator
                    Row(
                      children: [
                        // Name
                        Text(
                          widget.title ?? 'Suporte',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Simple online indicator
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            boxShadow:
                                isOnline
                                    ? [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                centerTitle: true,
                // Left-aligned back button
                leading: IconButton(
                  icon: const Icon(CupertinoIcons.back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              )
              : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!(widget.isAdminView && !widget.showAppBar)) ...[
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Mensagens',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Expanded(
                  child: Column(
                    children: [
                      // Messages area
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F8),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          child: messagesStream.when(
                            data: (messages) {
                              final realMessages = messages.where((m) => !m.isDefault).toList();
                              if (realMessages.isEmpty && !widget.isAdminView) {
                                return _buildEmptyStateUI(context);
                              } else if (realMessages.isEmpty && widget.isAdminView) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          CupertinoIcons.chat_bubble_2_fill,
                                          color: theme.colorScheme.primary,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Sem mensagens ainda',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              // Correctly use ScrollConfiguration with NoScrollbarBehavior
                              return ScrollConfiguration(
                                behavior: const NoScrollbarBehavior(),
                                child: ListView.builder(
                                  controller: _scrollController,
                                  reverse: true, 
                                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
                                  itemCount: realMessages.length,
                                  itemBuilder: (context, index) {
                                    final message = realMessages[index];
                                    return _buildMessageBubble(context, message, true);
                                  },
                                ),
                              );
                            },
                            loading: () => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Carregando mensagens...',
                                  style: TextStyle(
                                    color: theme.colorScheme.onBackground.withOpacity(
                                      0.7,
                                    ),
                                    fontSize: 14,
                                  ),
                                ),
                                if (kDebugMode)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      "Loading conversation: ${widget.conversationId}",
                                      style: TextStyle(
                                        color: theme.colorScheme.onBackground
                                            .withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                              ],
                            ),
                            error: (error, stack) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Erro ao carregar mensagens',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'Erro ao carregar mensagens: ${error.toString()}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onBackground.withOpacity(
                                        0.6,
                                      ),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (kDebugMode)
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      "Conversation ID: ${widget.conversationId}",
                                      style: TextStyle(
                                        color: theme.colorScheme.onBackground
                                            .withOpacity(0.5),
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ElevatedButton(
                                  onPressed: () {
                                    // Force refresh by rebuilding
                                    setState(() {});
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                  ),
                                  child: Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Input area - always visible
                      _buildMessageInput(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateUI(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(20),
            child: Icon(
              CupertinoIcons.chat_bubble_2,
              size: 40,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Bem-vindo ao Suporte',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: theme.colorScheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Conecte-se diretamente com nossa equipe de suporte para obter assistência personalizada com sua conta, serviços e quaisquer perguntas que você possa ter.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onBackground.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Envie uma mensagem para começar',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onBackground.withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessage message,
    bool showTime,
  ) {
    final theme = Theme.of(context);

    // Fix alignment logic:
    // If in admin view, align admin messages (isFromAdmin) to the right
    // If in user view, align user messages (isFromUser) to the right
    final isFromMe =
        widget.isAdminView ? message.isFromAdmin : message.isFromUser;

    final isFromAdmin = message.isFromAdmin;
    final isImage = message.isImage;

    // Determine sender name to display
    String senderName;
    if (isFromMe) {
      senderName = 'Você';
    } else if (isFromAdmin) {
      senderName = 'Suporte Twogether';
    } else {
      senderName = message.senderName ?? 'Utilizador';
    }

    // Set bubble colors based on sender and theme
    // Use transparent background for images
    final bubbleColor = isImage
            ? Colors.transparent
            : isFromMe
            ? theme.messageBubbleSent
            : theme.messageBubbleReceived;

    final textColor = isFromMe
            ? theme.messageBubbleTextSent
            : theme.messageBubbleTextReceived;

    // Set padding based on message type
    final contentPadding =
        isImage
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isFromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isFromMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor:
                isFromAdmin
                  ? theme.colorScheme.primary.withOpacity(0.2)
                  : theme.colorScheme.secondaryContainer,
              child: Text(
                senderName.isNotEmpty
                    ? senderName[0].toUpperCase()
                    : '?', // Fallback
                style: TextStyle(
                  color:
                    isFromAdmin
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isFromMe && senderName.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onBackground.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
                Container(
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: contentPadding,
                  child: _buildMessageContent(context, message, textColor),
                ),
                if (showTime)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                    child: Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onBackground.withOpacity(0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(
    BuildContext context,
    ChatMessage message,
    Color textColor,
  ) {
    final theme = Theme.of(context);
    final iphoneBlue = const Color(0xFF0B84FE); // Original iPhone-like blue color
    final iconGray = const Color(0xFF8E8E93); // iOS gray color for icons

    if (message.isImage) {
      // Debug logging for image messages
      if (kDebugMode) {
        print(
          'DEBUG: Image message detected. Raw content: \\${message.content.substring(0, min(100, message.content.length))}...',
        );
      }

      // Modern chat image style
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 220,
            maxHeight: 220,
          ),
          child: GestureDetector(
            onTap: () {
              // Show dialog with the image when tapped
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(10),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SafeNetworkImage(
                      imageUrl: message.content,
                      fit: BoxFit.contain,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SafeNetworkImage(
                imageUrl: message.content,
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(14),
                height: 220,
                width: 220,
              ),
            ),
          ),
        ),
      );
    } else if (message.type == MessageType.file) {
      // File message style
      return Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(14),
        ),
        child: GestureDetector(
          onTap: () async {
            try {
              final url = Uri.parse(message.content);
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              } else {
                if (kDebugMode) {
                  print('Could not launch $url');
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open file'),
                  ),
                );
              }
            } catch (e, stackTrace) {
              if (kDebugMode) {
                print('Error opening file: $e');
                print(stackTrace);
              }
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error opening file: ${e.toString()}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFileIcon(message.fileType ?? 'application/octet-stream'),
                  color: textColor,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.fileName ?? 'Unknown file',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (message.fileSize != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatFileSize(message.fileSize!),
                          style: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.download,
                  color: textColor.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Text(
        message.content,
        style: TextStyle(color: textColor, fontSize: 16),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.startsWith('image/')) return Icons.image;
    if (fileType.startsWith('video/')) return Icons.video_file;
    if (fileType.startsWith('audio/')) return Icons.audio_file;
    if (fileType.contains('pdf')) return Icons.picture_as_pdf;
    if (fileType.contains('word') || fileType.contains('document')) return Icons.description;
    if (fileType.contains('excel') || fileType.contains('sheet')) return Icons.table_chart;
    if (fileType.contains('powerpoint') || fileType.contains('presentation')) return Icons.slideshow;
    if (fileType.contains('zip') || fileType.contains('archive')) return Icons.archive;
    return Icons.insert_drive_file;
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
                                'Falha ao carregar imagem',
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
            fit: BoxFit.cover,
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
                      'Falha ao carregar imagem',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              );
            },
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
                    'Não é possível exibir a imagem',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Toque para abrir no navegador',
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (kIsWeb) ...[
            // On web, show only the file picker (covers images and files)
            ChatFilePicker(conversationId: widget.conversationId),
            const SizedBox(width: 12),
          ] else ...[
            // On mobile, show camera and gallery buttons
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isImageLoading ? null : () => _getImageFromSource(ImageSource.camera),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt_outlined, size: 20, color: theme.colorScheme.onPrimary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isImageLoading ? null : () => _getImageFromSource(ImageSource.gallery),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_outlined, size: 20, color: theme.colorScheme.onPrimary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Add file picker for files on mobile
            ChatFilePicker(conversationId: widget.conversationId),
            const SizedBox(width: 12),
          ],
          // Input + send button
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.dividerColor.withOpacity(0.18), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      textCapitalization: TextCapitalization.sentences,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: widget.isAdminView ? 'Mensagem' : 'Envie uma mensagem',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        filled: false,
                        fillColor: Colors.transparent,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      cursorColor: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: _hasText ? _sendMessage : null,
                    icon: Icon(
                      Icons.send_rounded,
                      color: _hasText
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                      size: 22,
                    ),
                    splashRadius: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Update _hasText state based on whether the input has text, with debounce
  void _updateHasText() {
    // Cancel previous timer if it exists
    _debounceTimer?.cancel();

    // Set a new timer to debounce the state update
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      final newHasText = _messageController.text.trim().isNotEmpty;
      if (_hasText != newHasText && mounted) {
        setState(() {
          _hasText = newHasText;
        });
      }
    });
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
            title: const Text('Info Depuração Carregamento Imagem'),
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
                    'Testes:',
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

  // Helper method to check if current time is within business hours (9am-6pm)
  bool _isBusinessHours() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 9 && hour < 18; // 9am to 6pm
  }
}

class SafeNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  bool _hasError = false;
  int _retryCount = 0;
  final int _maxRetries = 1; // Keep this at 1 to avoid excessive retries
  late String _processedUrl;
  bool _useBase64 = false;
  String? _base64Data;
  bool _isInitialized = false;
  bool _showPlaceholder = false; // Flag to show placeholder

  // Add a "corrupted" flag to identify permanently broken images
  bool _isCorrupted = false;

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
          if (content.containsKey('url')) {
            _processedUrl = content['url'] as String;

            // TEMPORARY WORKAROUND - Skip base64 for large images to avoid corruption issues
            // Only use base64 data if it's reasonably sized (< 50KB) and appears valid
            if (content.containsKey('base64') && content['base64'] is String) {
              final base64Raw = content['base64'] as String;
              if (base64Raw.isNotEmpty &&
                  base64Raw.length > 10 &&
                  base64Raw.length < 50000) {
                _base64Data = base64Raw;

                // For web, prefer base64 data if available
                if (kIsWeb && _base64Data != null && _base64Data!.isNotEmpty) {
                  _useBase64 = true;
                }

                if (kDebugMode) {
                  print('Found enhanced image content with base64 data');
                  print('Base64 data length: ${_base64Data!.length}');
                  print('Will use base64 for web: $_useBase64');
                }
              } else {
                if (kDebugMode) {
                  if (base64Raw.length >= 50000) {
                    print(
                      'Skipping base64 data for large image (${base64Raw.length} characters) - using URL only',
                    );
                  } else {
                    print(
                      'Base64 data found but appears too short or invalid: ${base64Raw.length} characters',
                    );
                  }
                }
                // Don't use base64 for large images or if it seems problematic
                _base64Data = null;
                _useBase64 = false;
              }
            } else {
              if (kDebugMode) {
                print('URL found in JSON, but no valid base64 data');
              }
              _base64Data = null;
              _useBase64 = false;
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
          // If we can't parse the JSON, mark it as corrupted
          _isCorrupted = true;
        }
      }

      // Regular URL processing
      _processedUrl = widget.imageUrl;

      // For Firebase Storage URLs, ensure they're properly formatted
      if (_processedUrl.contains('firebasestorage.googleapis.com')) {
        // Do not decode the URL as Firebase requires percent-encoding
        // _processedUrl remains unchanged

        // Make sure the URL has the alt=media parameter
        if (!_processedUrl.contains('alt=media')) {
          if (_processedUrl.contains('?')) {
            _processedUrl += '&alt=media';
          } else {
            _processedUrl += '?alt=media';
          }
        }

        // Add cache-busting parameter
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        if (_processedUrl.contains('?')) {
          _processedUrl += '&t=$timestamp';
        } else {
          _processedUrl += '?t=$timestamp';
        }

        if (kDebugMode) {
          print('Processed Firebase Storage URL: $_processedUrl');
        }

        // On mobile platforms, immediately try to get a fresh URL
        // to avoid using possibly expired URLs
        if (!kIsWeb) {
          try {
            final freshUrl = await _getFirebaseStorageUrl(_processedUrl);
            _processedUrl = freshUrl;
            if (kDebugMode) {
              print('Using fresh URL for mobile: $_processedUrl');
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                'Error getting fresh URL for mobile, using original URL: $e',
              );
            }
            // Continue with the original URL
          }
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
      _showPlaceholder = true;

      // Since this is async, we need to rebuild the widget
      if (mounted) setState(() {});
    }
  }

  void _resetAndRetry() {
    if (_isCorrupted || _retryCount >= _maxRetries) {
      // If the image is corrupted or we've exhausted retries, show placeholder
      setState(() {
        _showPlaceholder = true;
      });
      return;
    }

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
    // If we already know it's corrupted or have tried enough, show placeholder
    if (_isCorrupted || _showPlaceholder) {
      return _buildPlaceholderImage();
    }

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

    // If we've had an error and exhausted retries
    if (_hasError && _retryCount >= _maxRetries) {
      return _buildPlaceholderImage();
    }

    // Try using base64 data if available, for both web and mobile
    if (_useBase64 && _base64Data != null && _base64Data!.isNotEmpty) {
      try {
        // Handle both data URI format and plain base64
        if (_base64Data!.startsWith('data:image')) {
          // This is a data URI format
          final base64String = _base64Data!.split(',')[1];
          // Apply padding correction to truncated base64 data
          final paddedBase64 = _correctBase64Padding(base64String);
          return ClipRRect(
            borderRadius: widget.borderRadius,
            child: Image.memory(
              base64Decode(paddedBase64),
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('Error with base64 image: $error');
                }
                // Mark as corrupted if base64 fails
                _isCorrupted = true;
                // Show placeholder
                return _buildPlaceholderImage();
              },
            ),
          );
        } else {
          // Try to decode the plain base64 string
          // Apply padding correction to truncated base64 data
          final paddedBase64 = _correctBase64Padding(_base64Data!);
          return ClipRRect(
            borderRadius: widget.borderRadius,
            child: Image.memory(
              base64Decode(paddedBase64),
              fit: widget.fit,
              width: widget.width,
              height: widget.height,
              errorBuilder: (context, error, stackTrace) {
                if (kDebugMode) {
                  print('Error with plain base64 image: $error');
                }
                // Mark as corrupted if base64 fails
                _isCorrupted = true;
                // Show placeholder instead of retrying
                return _buildPlaceholderImage();
              },
            ),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error using base64 data: $e');
        }
        // Mark as corrupted
        _isCorrupted = true;
        return _buildPlaceholderImage();
      }
    }

    // If base64 wasn't used or failed, proceed with URL
    return _buildNetworkImage(_processedUrl);
  }

  // Helper method to build network image with proper error handling
  Widget _buildNetworkImage(String url) {
    // If we already know it's corrupted, don't even try
    if (_isCorrupted) {
      return _buildPlaceholderImage();
    }

    // For Firebase Storage URLs on web, try with FutureBuilder
    if (url.contains('firebasestorage.googleapis.com') && kIsWeb) {
      return FutureBuilder<String>(
        future: Future.any([
          _getFirebaseStorageUrl(url),
          // Add a shorter timeout to prevent endless loading
          Future.delayed(
            const Duration(seconds: 2),
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
            // Mark as corrupted
            _isCorrupted = true;
            return _buildPlaceholderImage();
          }

          final freshUrl = snapshot.data!;
          return _buildDirectNetworkImage(freshUrl);
        },
      );
    }

    // For regular URLs or Firebase on mobile, just use directly
    return _buildDirectNetworkImage(url);
  }

  // Helper method to build a regular network image
  Widget _buildDirectNetworkImage(String url) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        placeholder: (context, url) => _buildLoadingIndicator(null),
        errorWidget: (context, url, error) {
          if (kDebugMode) {
            print('Network image error: $error');
          }
          // Mark as corrupted
          _isCorrupted = true;
          // Show placeholder immediately
          return _buildPlaceholderImage();
        },
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
            'Imagem não disponível',
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

      // Don't decode the URL to preserve the encoding needed by Firebase Storage
      String storagePath = '';

      // Extract the path from the URL
      if (path.contains('/o/')) {
        // Standard extraction method
        final pathStart = path.indexOf('/o/') + 3;
        final pathEnd = path.contains('?') ? path.indexOf('?') : path.length;
        storagePath = path.substring(pathStart, pathEnd);

        // Don't decode the path - keep it percent-encoded for Firebase
        if (kDebugMode) {
          print('Extracted storage path: $storagePath');
        }
      } else {
        // For unusual URL formats, try to extract the filename
        final uriParts = path.split('/');
        final lastPart = uriParts.last;
        final fileName = lastPart.split('?').first;

        if (fileName.isNotEmpty) {
          // This looks like a filename
          if (fileName.contains('chat_images')) {
            storagePath = fileName;
          } else {
            storagePath = 'chat_images/$fileName';
          }

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
        try {
          // Get reference to the Firebase Storage location
          // Make sure to handle URL encoding correctly
          if (storagePath.startsWith('chat_images%2F')) {
            // This is likely a URL-encoded path, extract the filename
            final parts = storagePath.split('%2F');
            if (parts.length > 1) {
              final filename = parts[1];
              storagePath = 'chat_images/$filename';
              if (kDebugMode) {
                print('Reformatted encoded path to: $storagePath');
              }
            }
          }

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
        } catch (e) {
          if (kDebugMode) {
            print('Error getting fresh download URL: $e');

            // Try a fallback approach for certain error types
            if (e.toString().contains('object-not-found')) {
              // This could be a URL encoding issue, try with an alternative path format
              try {
                if (storagePath.contains('%2F')) {
                  // Try with decoded path
                  final decodedPath = Uri.decodeComponent(storagePath);
                  final ref = FirebaseStorage.instance.ref(decodedPath);
                  final freshUrl = await ref.getDownloadURL();

                  if (kDebugMode) {
                    print('Success with decoded path: $freshUrl');
                  }

                  return freshUrl;
                }
              } catch (fallbackError) {
                if (kDebugMode) {
                  print('Fallback approach also failed: $fallbackError');
                }
              }
            }
          }
          throw e;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting fresh download URL: $e');
      }
      // Any error, just let it fail so we show the placeholder
      rethrow;
    }

    // If anything fails, return the original URL with a cache-busting parameter
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.contains('?') ? '$path&t=$timestamp' : '$path?t=$timestamp';
  }

  // Add a helper method to correct base64 padding if it was truncated
  String _correctBase64Padding(String base64String) {
    try {
      // First, sanitize by removing any invalid characters that might have resulted from truncation
      // Only keep valid base64 characters (A-Za-z0-9+/)
      final sanitizedString = base64String.replaceAll(
        RegExp(r'[^A-Za-z0-9+/]'),
        '',
      );

      if (sanitizedString.length != base64String.length && kDebugMode) {
        print(
          'Sanitized base64 string (removed ${base64String.length - sanitizedString.length} invalid characters)',
        );
      }

      // Base64 data must have a length that is a multiple of 4
      // If it doesn't, we need to add padding characters ('=')
      if (sanitizedString.length % 4 != 0) {
        if (kDebugMode) {
          print('Correcting base64 padding for truncated data');
        }
        if (kDebugMode) {
          print('Original length: ${base64String.length}');
        }
        if (kDebugMode) {
          print('Sanitized length: ${sanitizedString.length}');
        }

        // Calculate how many padding characters we need to add
        final paddingLength = 4 - (sanitizedString.length % 4);
        final paddedString = sanitizedString + ('=' * paddingLength);

        if (kDebugMode) {
          print('Padded length: ${paddedString.length}');
        }

        return paddedString;
      }

      return sanitizedString;
    } catch (e) {
      if (kDebugMode) {
        print('Error correcting base64 padding: $e');
      }
      // Return the original string if any error occurs during correction
      return base64String;
    }
  }
}
