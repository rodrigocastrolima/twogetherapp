import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:async';
import '../../../../core/theme/ui_styles.dart';
import '../../domain/models/chat_conversation.dart';
import '../providers/chat_provider.dart';
import 'chat_page.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../../presentation/widgets/simple_list_item.dart';
import 'package:go_router/go_router.dart';

// Provider to fetch all resellers
final resellersProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'reseller')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['displayName'] ?? data['email'] ?? 'Unknown User',
                'email': data['email'] ?? '',
              };
            }).toList(),
      );
});

class AdminChatPage extends ConsumerStatefulWidget {
  const AdminChatPage({super.key});

  @override
  ConsumerState<AdminChatPage> createState() => _AdminChatPageState();
}

class _AdminChatPageState extends ConsumerState<AdminChatPage> {
  // State variable to track if we're showing only active conversations
  // bool _showOnlyActive = true; // Removed unused variable

  // Search query
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Add a PageController to manage the page view
  final PageController _pageController = PageController(initialPage: 0);

  // --- NEW: State for split view selection ---
  Map<String, dynamic>? _selectedReseller;
  ChatConversation? _selectedConversation;

  late final ChatRepository _chatRepo;

  @override
  void initState() {
    super.initState();
    _chatRepo = ref.read(chatRepositoryProvider);
    _searchController.addListener(_onSearchChanged);

    // Add listener to page controller to update the current page value
    _pageController.addListener(() {
      // setState(() {
      //   _currentPage = _pageController.page ?? 0;
      //   // Update the filter state when page changes
      //   // _showOnlyActive = _currentPage < 0.5;
      // });
    });

    // Check if userId is passed via state.extra and open the conversation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = GoRouterState.of(context);
      final extra = state.extra as Map<String, dynamic>?;
      final userId = extra?['userId'] as String?;
      if (userId != null) {
        _openConversationForUser(userId);
      }
    });
  }

  @override
  void dispose() {
    // On page leave, set admin as inactive in the last selected conversation
    if (_selectedConversation != null) {
      _chatRepo.setUserActiveInConversation(_selectedConversation!.id, false);
    }
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Watch both conversations and resellers
    final conversationsStream = ref.watch(conversationsProvider);
    final resellersStream = ref.watch(resellersProvider);

    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Row(
            children: [
              // LEFT PANEL: List
              SizedBox(
                width: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
              child: Text(
                'Mensagens',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  style: theme.textTheme.bodyMedium,
                  decoration: AppStyles.searchInputDecoration(context, 'Pesquisar Conversas...'),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = _searchController.text.trim().toLowerCase();
                    });
                  },
                ),
              ),
            ),
            // --- List ---
            Expanded(
                    child: resellersStream.when(
                      data: (resellers) {
                        if (resellers.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.person_3_fill,
                                  size: 48,
                            color: theme.colorScheme.primary.withAlpha((255 * 0.5).round()),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhum usuário revendedor encontrado',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return conversationsStream.when(
                          data: (conversations) {
                            // Create maps of conversations by reseller ID
                            final conversationsByResellerId = <String, ChatConversation>{};
                            for (var conversation in conversations) {
                              conversationsByResellerId[conversation.resellerId] = conversation;
                            }

                            // Apply search filter to all resellers (not just those with conversations)
                            final filteredResellers = _searchQuery.isEmpty
                                ? resellers
                                : resellers.where((reseller) {
                                    // Search in name and email
                                    return (reseller['name'] ?? '')
                                            .toLowerCase()
                                            .contains(_searchQuery) ||
                                        (reseller['email'] ?? '')
                                            .toLowerCase()
                                            .contains(_searchQuery);
                                  }).toList();

                            // Sort resellers: those with conversations first (by last message time), then alphabetically
                            final sortedResellers = List<Map<String, dynamic>>.from(filteredResellers);
                            sortedResellers.sort((a, b) {
                              final conversationA = conversationsByResellerId[a['id']];
                              final conversationB = conversationsByResellerId[b['id']];
                              
                              // If both have conversations, sort by last message time
                              if (conversationA != null && conversationB != null) {
                                final timeA = conversationA.lastMessageTime;
                                final timeB = conversationB.lastMessageTime;
                                if (timeA != null && timeB != null) {
                                  return timeB.compareTo(timeA);
                                } else if (timeA != null) {
                                  return -1;
                                } else if (timeB != null) {
                                  return 1;
                                }
                              }
                              // If only one has a conversation, prioritize it
                              else if (conversationA != null) {
                                return -1;
                              } else if (conversationB != null) {
                                return 1;
                              }
                              
                              // If neither has conversations, sort alphabetically by name
                              return (a['name'] as String? ?? '').compareTo(
                                b['name'] as String? ?? '',
                              );
                            });

                            if (sortedResellers.isEmpty) {
                              // Handle empty state after filtering
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      CupertinoIcons.search,
                                      size: 48,
                                      color: theme.colorScheme.primary
                                          .withAlpha((255 * 0.5).round()),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Nenhum revendedor encontrado",
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? "Tente ajustar sua pesquisa."
                                          : "Comece uma nova conversa!",
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withAlpha((255 * 0.6).round()),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    // Optional: Add button to clear search
                                    if (_searchQuery.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 16.0,
                                        ),
                                        child: CupertinoButton(
                                          child: Text("Limpar Pesquisa"),
                                          onPressed:
                                              () => _searchController.clear(),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }

                            // Build the list using sortedResellers
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                        itemCount: sortedResellers.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 0),
                        itemBuilder: (context, index) {
                          final reseller = sortedResellers[index];
                          final conversation = conversationsByResellerId[reseller['id']];
                          final isSelected = isWide && _selectedReseller?['id'] == reseller['id'];
                          final hasUnread = conversation?.unreadByAdmin ?? false;
                          final hasConversation = conversation != null;
                          
                          // Determine what to show as subtitle
                          String subtitle;
                          if (hasConversation && (conversation.lastMessageContent?.isNotEmpty ?? false)) {
                            subtitle = conversation.lastMessageContent!;
                          } else if (hasConversation) {
                            subtitle = 'Conversa iniciada';
                          } else {
                            subtitle = reseller['email'] ?? '';
                          }
                          
                          String? formattedDate;
                          if (conversation?.lastMessageTime != null) {
                            final now = DateTime.now();
                            final last = conversation!.lastMessageTime!;
                            if (now.difference(last).inDays == 0) {
                              formattedDate = DateFormat('HH:mm').format(last);
                            } else if (now.difference(last).inDays == 1) {
                              formattedDate = 'Ontem';
                            } else if (now.year == last.year) {
                              formattedDate = DateFormat('d MMM').format(last);
                            } else {
                              formattedDate = DateFormat('dd/MM/yy').format(last);
                            }
                          }
                          
                          final yellow = Color(0xFFFFBE45);
                          return Container(
                            color: isSelected ? theme.colorScheme.primary.withAlpha((255 * 0.08).round()) : null,
                            child: SimpleListItem(
                              leading: Container(
                                width: 40,
                                height: 40,
                                    decoration: BoxDecoration(
                                  color: hasUnread
                                      ? yellow.withAlpha((255 * 0.15).round())
                                      : hasConversation
                                          ? theme.colorScheme.surface
                                          : theme.colorScheme.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Icon(
                                    CupertinoIcons.person,
                                    size: 20,
                                    color: hasUnread
                                        ? yellow
                                        : hasConversation
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              title: reseller['name'],
                              subtitle: subtitle,
                              trailing: formattedDate != null
                                  ? Text(
                                      formattedDate,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        fontSize: 12,
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                if (isWide) {
                                  _onSelectConversation(reseller, conversation);
                                } else {
                                  _openOrCreateChat(context, reseller);
                                }
                              },
                              padding: EdgeInsets.symmetric(vertical: 0),
                              titleStyle: hasUnread
                                  ? theme.textTheme.bodyLarge?.copyWith(
                                      color: yellow,
                                      fontWeight: FontWeight.w700,
                                                )
                                                : null,
                            ),
                          );
                        },
                    );
                  },
                    loading: () => const Center(child: CupertinoActivityIndicator()),
                    error: (error, stack) => Center(
                                child: Text(
                                  'Error loading conversations: $error',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                        );
                      },
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (error, stack) => Center(
                            child: Text(
                              'Error loading resellers: $error',
                              style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
              // RIGHT PANEL: Chat
                  Expanded(
                child: isWide
                    ? (_selectedReseller == null
                        ? Center(child: Text('Selecione uma conversa'))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              if (_selectedReseller != null) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32), // match message container/input bar
                                  child: Container(
                                    color: theme.colorScheme.surface,
                                    padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.secondaryContainer,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              CupertinoIcons.person,
                                              size: 26,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedReseller?['name'] ?? '',
                                              style: theme.textTheme.headlineSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _selectedReseller?['email'] ?? '',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Divider(
                                    height: 1,
                                    thickness: 0.7,
                                    color: theme.dividerColor.withAlpha((255 * 0.12).round()),
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  child: ChatPage(
                                    conversationId: _selectedConversation?.id ?? '',
                                    title: _selectedReseller?['name'] ?? 'Chat',
                                    isAdminView: true,
                                    showAppBar: false,
                                  ),
                                ),
                              ),
                            ],
                          ))
                    : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          ),
    );
  }

  void _onSelectConversation(Map<String, dynamic> reseller, ChatConversation? conversation) async {
    // Set previous as inactive
    if (_selectedConversation != null && _selectedConversation!.id != conversation?.id) {
      await _chatRepo.setUserActiveInConversation(_selectedConversation!.id, false);
    }
    if (conversation == null) {
      // Create a new conversation for this reseller
      final conversationData = {
        'resellerId': reseller['id'],
        'resellerName': reseller['name'],
        'lastMessageContent': null,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageIsFromAdmin': null,
        'active': false,
        'unreadByAdmin': false,
        'unreadByReseller': false,
        'unreadCount': 0,
        'unreadCounts': {},
        'createdAt': FieldValue.serverTimestamp(),
        'participants': ['admin', reseller['id']],
        'activeUsers': ['admin', reseller['id']],
      };
      final docRef = await FirebaseFirestore.instance
          .collection('conversations')
          .add(conversationData);
      final doc = await docRef.get();
      final data = doc.data() as Map<String, dynamic>;
      final newConversation = ChatConversation(
        id: doc.id,
        resellerId: reseller['id'],
        resellerName: reseller['name'],
        lastMessageContent: data['lastMessageContent'],
        lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
        active: data['active'] ?? false,
        unreadCounts: data['unreadCounts'] != null ? Map<String, int>.from(data['unreadCounts']) : {},
      );
      setState(() {
        _selectedReseller = reseller;
        _selectedConversation = newConversation;
      });
      await _chatRepo.setUserActiveInConversation(newConversation.id, true);
      await _chatRepo.markConversationAsRead(newConversation.id, true);
    } else {
      setState(() {
        _selectedReseller = reseller;
        _selectedConversation = conversation;
      });
      await _chatRepo.setUserActiveInConversation(conversation.id, true);
      await _chatRepo.markConversationAsRead(conversation.id, true);
    }
  }

  Future<void> _openOrCreateChat(
    BuildContext context,
    Map<String, dynamic> reseller,
  ) async {
    try {
      // Find existing conversation for this reseller
      String conversationId = '';
      // Query for conversations with this reseller
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('conversations')
              .where('resellerId', isEqualTo: reseller['id'])
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        // Use existing conversation
        conversationId = snapshot.docs.first.id;
      } else {
        // Create a new conversation
        final conversationData = {
          'resellerId': reseller['id'],
          'resellerName': reseller['name'],
          'lastMessageContent': null,
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageIsFromAdmin': null,
          'active': false,
          'unreadByAdmin': false,
          'unreadByReseller': false,
          'unreadCount': 0,
          'unreadCounts': {},
          'createdAt': FieldValue.serverTimestamp(),
          'participants': ['admin', reseller['id']],
          'activeUsers': ['admin', reseller['id']],
        };
        final docRef = await FirebaseFirestore.instance
            .collection('conversations')
            .add(conversationData);
        conversationId = docRef.id;
      }

      // Only open chat if conversationId is not empty
      if (conversationId.isNotEmpty && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatPage(
                  conversationId: conversationId,
                  title: reseller['name'] ?? 'Chat',
                  isAdminView: true,
                  showAppBar: true,
                ),
          ),
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao criar conversa.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openConversationForUser(String userId) async {
    try {
      // First get the reseller data
      final resellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!resellerDoc.exists) return;
      
      final resellerData = resellerDoc.data()!;
      final reseller = {
        'id': userId,
        'name': resellerData['displayName'] ?? resellerData['email'] ?? 'Unknown User',
        'email': resellerData['email'] ?? '',
      };

      // Then get the conversation
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .where('resellerId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _selectedReseller = reseller; // Set the reseller
          _selectedConversation = ChatConversation(
            id: doc.id,
            resellerId: userId,
            resellerName: data['resellerName'] ?? '',
            lastMessageContent: data['lastMessageContent'],
            lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
            active: data['active'] ?? false,
            unreadCounts: data['unreadCounts'] != null ? Map<String, int>.from(data['unreadCounts']) : {},
          );
        });
        
        // Also set the conversation as active and mark as read
        await _chatRepo.setUserActiveInConversation(doc.id, true);
        await _chatRepo.markConversationAsRead(doc.id, true);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error opening conversation for user: $e');
      }
    }
  }
}
