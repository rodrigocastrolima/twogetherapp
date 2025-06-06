import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../../domain/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../../../core/theme/ui_styles.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import '../../../../core/theme/theme.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../presentation/widgets/secure_file_viewer.dart';
import 'package:file_picker/file_picker.dart';

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
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isImageLoading = false;
  bool _hasText = false; // Add this to track whether there's text in the input
  Timer? _debounceTimer; // Add debounce timer to prevent too many updates
  late final ChatNotifier _chatNotifier; // <-- ADD member variable

  // Add state for file/image attachments
  dynamic _selectedFile; // Can be XFile or File
  String? _selectedFileName;
  String? _selectedFileType;
  int? _selectedFileSize;
  bool _isAttachmentImage = false;

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
    final hasText = text.isNotEmpty;
    final hasAttachment = _selectedFile != null;
    
    if (!hasText && !hasAttachment) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Clear the input immediately for better UX
      _messageController.clear();
      final fileToSend = _selectedFile;
      final fileName = _selectedFileName;
      final fileType = _selectedFileType;
      final fileSize = _selectedFileSize;
      final isImage = _isAttachmentImage;
      
      // Clear attachment state
      _removeAttachment();

      // Send text message first if there is text
      if (hasText) {
        await ref
            .read(chatNotifierProvider.notifier)
            .sendTextMessage(widget.conversationId, text);
      }

      // Send attachment if there is one
      if (hasAttachment) {
        if (isImage) {
          await ref
              .read(chatNotifierProvider.notifier)
              .sendImageMessage(widget.conversationId, fileToSend);
        } else {
          await ref
              .read(chatNotifierProvider.notifier)
              .sendFileMessage(
                widget.conversationId,
                fileToSend,
                fileName!,
                fileType!,
                fileSize!,
              );
        }
      }

      // Scroll to bottom after messages are sent
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

      // Mark as read automatically when we send messages
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

      // Set as attachment instead of showing preview
      final fileSize = await pickedImage.length();
      setState(() {
        _selectedFile = pickedImage;
        _selectedFileName = pickedImage.name;
        _selectedFileType = 'image/${pickedImage.path.split('.').last.toLowerCase()}';
        _selectedFileSize = fileSize;
        _isAttachmentImage = true;
        _isImageLoading = false;
      });

      // Focus on the text input so user can add a message
      _focusNode.requestFocus();

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.showAppBar ? null : null,
      body: SafeArea(
        bottom: true,
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!(widget.isAdminView && !widget.showAppBar)) ...[
              // Responsive spacing after SafeArea - no spacing for mobile, 24px for desktop
              SizedBox(height: MediaQuery.of(context).size.width < 600 ? 0 : 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Mensagens',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                    fontSize: _getResponsiveFontSize(context, 24),
                  ),
                ),
              ),
              // Responsive spacing after title - 24px for mobile, 32px for desktop
              SizedBox(height: MediaQuery.of(context).size.width < 600 ? 16 : 24),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Messages area
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.border(isDark ? Brightness.dark : Brightness.light),
                            width: 1,
                          ),
                        ),
                        margin: EdgeInsets.zero, // Remove horizontal margin here
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
                                        color: theme.colorScheme.primary.withAlpha(25),
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
                                  color: theme.colorScheme.onSurface.withAlpha(
                                    (255 * 0.7).round(),
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
                                      color: theme.colorScheme.onSurface
                                          .withAlpha((255 * 0.5).round()),
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
                                    color: theme.colorScheme.onSurface.withAlpha(
                                      (255 * 0.6).round(),
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
                                      color: theme.colorScheme.onSurface
                                          .withAlpha((255 * 0.5).round()),
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
                  ],
                ),
              ),
            ),
            // Input area - always visible, outside the chat container
            _buildMessageInput(),
          ],
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
                color: theme.colorScheme.onSurface,
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
                color: theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
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
                color: theme.colorScheme.onSurface.withAlpha((255 * 0.5).round()),
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
    final isDark = theme.brightness == Brightness.dark;

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
      senderName = message.senderName;
    }

    // Set bubble colors based on sender and theme
    // Use transparent background for images
    final bubbleColor = isImage
        ? Colors.transparent
        : isFromMe
            ? const Color(0xFF007AFF) // Apple blue for sent messages
            : (isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0)); // Dark gray for dark mode, light gray for light mode

    final textColor = isImage
        ? Colors.transparent
        : isFromMe
            ? Colors.white // White text on blue background
            : AppColors.foreground(isDark ? Brightness.dark : Brightness.light);

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
                  ? theme.colorScheme.primary.withAlpha((255 * 0.2).round())
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
                        color: theme.colorScheme.onSurface.withAlpha((255 * 0.7).round()),
                      ),
                    ),
                  ),
                ],
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7, // 70% of screen width max
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: contentPadding,
                    child: _buildMessageContent(context, message, textColor),
                  ),
                ),
                if (showTime)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                    child: Text(
                      DateFormat('HH:mm').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.foregroundMuted(isDark ? Brightness.dark : Brightness.light),
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
              color: Colors.black.withAlpha((255 * 0.08).round()),
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
              // Parse the content to extract the URL if it's JSON
              String imageUrl = message.content;
              try {
                if (message.content.startsWith('{') && message.content.endsWith('}')) {
                  final contentData = json.decode(message.content) as Map<String, dynamic>;
                  imageUrl = contentData['url'] as String? ?? message.content;
                }
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing image content JSON, using as-is: $e');
                }
                // Use the original content if parsing fails
              }
              
              // Show dialog with the image when tapped
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SecureFileViewer.fromUrl(
                    url: imageUrl,
                    title: 'Imagem do Chat',
                    fileType: 'image',
                  ),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SafeNetworkImage(
                imageUrl: (() {
                  // Parse the content to extract the URL if it's JSON
                  try {
                    if (message.content.startsWith('{') && message.content.endsWith('}')) {
                      final contentData = json.decode(message.content) as Map<String, dynamic>;
                      return contentData['url'] as String? ?? message.content;
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print('Error parsing thumbnail content JSON, using as-is: $e');
                    }
                  }
                  return message.content;
                })(),
                fit: BoxFit.contain,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    } else if (message.type == MessageType.file) {
      // File message style
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 220,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: GestureDetector(
            onTap: () {
              // Use SecureFileViewer for files as well
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SecureFileViewer.fromUrl(
                    url: message.content,
                    title: message.fileName ?? 'Arquivo',
                    fileType: message.fileType,
                  ),
                ),
              );
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
                              color: textColor.withAlpha((255 * 0.7).round()),
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
                    color: textColor.withAlpha((255 * 0.7).round()),
                    size: 20,
                  ),
                ],
              ),
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

  Widget _buildMessageInput() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Define button colors - match input field
    final buttonColor = AppColors.input(isDark ? Brightness.dark : Brightness.light);
    final buttonIconColor = AppColors.foregroundVariant(isDark ? Brightness.dark : Brightness.light);
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // Attachment preview (if any)
          if (_selectedFile != null) _buildAttachmentPreview(),
          SizedBox(height: 8),
          // Main input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (kIsWeb) ...[
                // On web, show only the file picker (covers images and files)
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _pickFile,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: buttonColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.border(isDark ? Brightness.dark : Brightness.light),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.attach_file, size: 20, color: buttonIconColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                // On mobile, show single plus button with popup menu
                                Theme(
                  data: Theme.of(context).copyWith(
                    splashFactory: NoSplash.splashFactory,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, -160), // Position above the button, aligned with chat container
                    enabled: !_isImageLoading,
                    elevation: 8,
                    color: isDark ? const Color(0xFF3A3A3A) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: buttonColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.border(isDark ? Brightness.dark : Brightness.light),
                          width: 1,
                        ),
                      ),
                      child: Icon(CupertinoIcons.plus, size: 20, color: buttonIconColor),
                    ),
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'camera',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.camera, size: 18, color: AppColors.foreground(isDark ? Brightness.dark : Brightness.light)),
                              const SizedBox(width: 12),
                              Text('Tirar Foto', style: TextStyle(color: AppColors.foreground(isDark ? Brightness.dark : Brightness.light))),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'gallery',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.photo, size: 18, color: AppColors.foreground(isDark ? Brightness.dark : Brightness.light)),
                              const SizedBox(width: 12),
                              Text('Escolher da Galeria', style: TextStyle(color: AppColors.foreground(isDark ? Brightness.dark : Brightness.light))),
                            ],
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'file',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            children: [
                              Icon(CupertinoIcons.doc, size: 18, color: AppColors.foreground(isDark ? Brightness.dark : Brightness.light)),
                              const SizedBox(width: 12),
                              Text('Anexar Arquivo', style: TextStyle(color: AppColors.foreground(isDark ? Brightness.dark : Brightness.light))),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onSelected: (String value) {
                      switch (value) {
                        case 'camera':
                          _getImageFromSource(ImageSource.camera);
                          break;
                        case 'gallery':
                          _getImageFromSource(ImageSource.gallery);
                          break;
                        case 'file':
                          _pickFile();
                          break;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Input + send button
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: AppColors.input(isDark ? Brightness.dark : Brightness.light),
                    border: Border.all(color: AppColors.border(isDark ? Brightness.dark : Brightness.light), width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectionContainer.disabled(
                          child: Theme(
                            data: theme.copyWith(
                              textSelectionTheme: TextSelectionThemeData(
                                cursorColor: AppColors.foreground(isDark ? Brightness.dark : Brightness.light),
                                selectionColor: Colors.transparent,
                                selectionHandleColor: Colors.transparent,
                              ),
                            ),
                            child: TextField(
                              controller: _messageController,
                              focusNode: _focusNode,
                              textCapitalization: TextCapitalization.sentences,
                              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.foreground(isDark ? Brightness.dark : Brightness.light)),
                              decoration: InputDecoration(
                                hintText: _selectedFile != null 
                                    ? 'Adicionar mensagem...' 
                                    : (widget.isAdminView ? 'Mensagem' : 'Envie uma mensagem'),
                                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: AppColors.foregroundMuted(isDark ? Brightness.dark : Brightness.light)),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                errorBorder: InputBorder.none,
                                focusedErrorBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                filled: false,
                                fillColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                              ),
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              cursorColor: AppColors.foreground(isDark ? Brightness.dark : Brightness.light),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: (_hasText || _selectedFile != null) ? _sendMessage : null,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        icon: Icon(
                          Icons.send_rounded,
                          color: (_hasText || _selectedFile != null)
                              ? AppColors.primary(isDark ? Brightness.dark : Brightness.light)
                              : AppColors.foregroundMuted(isDark ? Brightness.dark : Brightness.light),
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
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark ? Brightness.dark : Brightness.light),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border(isDark ? Brightness.dark : Brightness.light),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // File icon or image preview
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getFileIcon(_selectedFileType ?? 'application/octet-stream'),
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName ?? 'Unknown file',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.foreground(isDark ? Brightness.dark : Brightness.light),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedFileSize != null ? _formatFileSize(_selectedFileSize!) : '',
                  style: TextStyle(
                    color: AppColors.foregroundMuted(isDark ? Brightness.dark : Brightness.light),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Remove button
          IconButton(
            onPressed: _removeAttachment,
            icon: Icon(
              Icons.close,
              color: AppColors.foregroundMuted(isDark ? Brightness.dark : Brightness.light),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
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

  // Helper method to check if current time is within business hours (9am-6pm)
  bool _isBusinessHours() {
    final now = DateTime.now();
    final hour = now.hour;
    return hour >= 9 && hour < 18; // 9am to 6pm
  }

  // Helper method for responsive font sizing
  double _getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    return width < 600 ? baseFontSize - 2 : baseFontSize;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        if (kDebugMode) {
          print('No file selected');
        }
        return;
      }

      final file = result.files.first;
      if (kDebugMode) {
        print('Selected file: ${file.name}');
        print('File size: ${file.size}');
        print('File type: ${file.extension}');
      }

      // Set as attachment
      setState(() {
        _selectedFile = kIsWeb ? file : File(file.path!);
        _selectedFileName = file.name;
        _selectedFileType = file.extension ?? 'application/octet-stream';
        _selectedFileSize = file.size;
        _isAttachmentImage = false; // This is a file, not an image
      });

      // Focus on the text input so user can add a message
      _focusNode.requestFocus();

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error picking file: $e');
        print(stackTrace);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _removeAttachment() {
    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _selectedFileType = null;
      _selectedFileSize = null;
      _isAttachmentImage = false;
    });
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
  final bool _hasError = false;
  final int _retryCount = 0;
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
            _processedUrl = content['url'] as String? ?? widget.imageUrl;

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
          value: () {
            final expectedBytes = loadingProgress?.expectedTotalBytes;
            return expectedBytes != null
                ? loadingProgress!.cumulativeBytesLoaded / expectedBytes
                : null;
          }(),
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
          }

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
        if (kDebugMode) {
          print(
            'Sanitized base64 string (removed ${base64String.length - sanitizedString.length} invalid characters)',
          );
        }
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
