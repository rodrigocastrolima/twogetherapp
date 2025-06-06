import 'dart:io' as io;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_conversation.dart';

class ChatRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  // Collection names
  static const String _conversationsCollection = 'conversations';
  static const String _messagesCollection = 'messages';

  // Message expiration duration - messages older than this will be deleted
  static int messageExpirationDays = 7;

  // Safety constraints
  static const int _maxMessageLength = 1000; // Maximum characters per message
  static const int _maxImageSizeMB = 5; // Maximum image size in MB
  static const int _maxFileSizeMB = 20; // Maximum file size in MB
  static const int _messageRateLimitPerMinute =
      30; // Maximum messages per minute

  // Rate limiting
  final Map<String, List<DateTime>> _messageSendTimes = {};

  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _auth = auth ?? FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Configure the message expiration period
  static void setMessageExpirationDays(int days) {
    if (days > 0) {
      messageExpirationDays = days;
    }
  }

  // Note: Message cleanup is now handled by a Firebase Cloud Function
  // that runs on a daily schedule

  // Check if user is admin
  Future<bool> isCurrentUserAdmin() async {
    if (currentUserId == null) return false;

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final roleData = userData['role'];
      final String roleString = roleData is String ? roleData : 'unknown';
      final normalizedRole = roleString.trim().toLowerCase();

      return normalizedRole == 'admin';
    } catch (e) {
      if (kDebugMode) {
        print('Error checking if user is admin: $e');
      }
      return false;
    }
  }

  // Get current user's name
  Future<String> getCurrentUserName() async {
    if (currentUserId == null) return 'Unknown User';

    try {
      final userDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      if (!userDoc.exists) return 'Unknown User';

      final userData = userDoc.data()!;
      return userData['displayName'] ?? userData['email'] ?? 'Unknown User';
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user name: $e');
      }
      return 'Unknown User';
    }
  }

  /// Ensures that a reseller has a default conversation
  /// This can be called during user creation or login to make sure every reseller has a conversation
  Future<String> ensureResellerHasConversation(String resellerId) async {
    try {
      if (kDebugMode) {
        print('Ensuring reseller $resellerId has a conversation');
      }

      // Check if a conversation already exists for this reseller
      final QuerySnapshot querySnapshot =
          await _firestore
              .collection(_conversationsCollection)
              .where('resellerId', isEqualTo: resellerId)
              .limit(1)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        if (kDebugMode) {
          print('Found existing conversation for reseller: $resellerId');
        }
        // Conversation exists, return its ID
        return querySnapshot.docs.first.id;
      } else {
        if (kDebugMode) {
          print(
            'No conversation found, creating one for reseller: $resellerId',
          );
        }

        // Get the reseller info from the users collection
        final userDoc =
            await _firestore.collection('users').doc(resellerId).get();

        if (!userDoc.exists) {
          if (kDebugMode) {
            print('Reseller not found in users collection: $resellerId');
          }
          throw Exception('Reseller not found');
        }

        final String displayName =
            userDoc.data()?['displayName'] ??
            userDoc.data()?['email'] ??
            'Unknown User';

        if (kDebugMode) {
          print(
            'Creating conversation for reseller: $displayName ($resellerId)',
          );
        }

        // Create a new conversation - WITHOUT lastMessageContent/Time or active state
        final conversationData = {
          'resellerId': resellerId,
          'resellerName': displayName,
          // Don't include lastMessageContent or lastMessageTime - they'll be set when actual messages are sent
          // Always start as inactive until real messages are sent
          'active': false,
          // Initialize with empty unread counts
          'unreadCounts': {},
          'unreadByAdmin': false,
          'unreadByReseller': false,
          'unreadCount': 0,
          'participants': ['admin', resellerId],
          'activeUsers': [],
          'createdAt': FieldValue.serverTimestamp(),
        };

        try {
          // Create the conversation document
          final docRef = await _firestore
              .collection(_conversationsCollection)
              .add(conversationData);

          final conversationId = docRef.id;

          if (kDebugMode) {
            print('Created new conversation with ID: $conversationId');
          }

          // Don't add a default welcome message to the database
          // The welcome message will be added by the UI when needed

          return conversationId;
        } catch (e) {
          if (kDebugMode) {
            print('Error creating conversation document: $e');
          }

          // Try an alternative approach if the first attempt fails
          // This uses a transaction to ensure atomicity
          final String conversationId =
              _firestore.collection(_conversationsCollection).doc().id;

          await _firestore.runTransaction((transaction) async {
            // Create the conversation document with a predefined ID
            transaction.set(
              _firestore
                  .collection(_conversationsCollection)
                  .doc(conversationId),
              conversationData,
            );
          });

          if (kDebugMode) {
            print(
              'Created conversation using transaction approach: $conversationId',
            );
          }

          return conversationId;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error ensuring reseller has conversation: $e');
      }
      throw Exception('Failed to create conversation for reseller: $e');
    }
  }

  /// Get or create a conversation for the current reseller
  Future<String> getOrCreateConversation() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      return await ensureResellerHasConversation(currentUser.uid);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting or creating conversation: $e');
      }
      throw Exception('Failed to get or create conversation: $e');
    }
  }

  // Get all conversations (for admin)
  Stream<List<ChatConversation>> getConversations() {
    return _firestore
        .collection(_conversationsCollection)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatConversation.fromFirestore(doc))
                  .toList(),
        );
  }

  // Get messages for a conversation
  Stream<List<ChatMessage>> getMessages(String conversationId) {
    if (kDebugMode) {
      print('Repository: Getting messages for conversation $conversationId');
    }

    try {
      return _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            if (kDebugMode) {
              print(
                'Received ${snapshot.docs.length} messages for $conversationId',
              );
            }

            return snapshot.docs.map((doc) {
              try {
                return ChatMessage.fromFirestore(doc);
              } catch (e) {
                if (kDebugMode) {
                  print('Error parsing message ${doc.id}: $e');
                  print('Document data: ${doc.data()}');
                }
                // Return a placeholder message if something went wrong
                return ChatMessage(
                  id: doc.id,
                  senderId: 'system',
                  senderName: 'System',
                  content: '[Error loading message]',
                  type: MessageType.text,
                  timestamp: DateTime.now(),
                  isAdmin: true,
                );
              }
            }).toList();
          })
          .handleError((error) {
            if (kDebugMode) {
              print('Error in messages stream for $conversationId: $error');
            }
            // Return an empty list on error
            return [];
          });
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing messages stream for $conversationId: $e');
      }
      // Return an empty stream
      return Stream.value([]);
    }
  }

  // Mark conversation as read by participant
  Future<void> markConversationAsRead(
    String conversationId,
    bool isAdmin,
  ) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Update the conversation document
      final Map<String, dynamic> updateData = {};

      if (isAdmin) {
        // If admin, mark admin's unread count as 0
        updateData['unreadCounts.admin'] = 0;
        updateData['unreadByAdmin'] = false;
      } else {
        // If reseller, mark their unread count as 0
        updateData['unreadCounts.$currentUserId'] = 0;
        updateData['unreadByReseller'] = false;
      }

      // Update the document
      await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .update(updateData);
    } catch (e) {
      if (kDebugMode) {
        print('Error marking conversation as read: $e');
      }
      throw Exception('Failed to mark conversation as read: $e');
    }
  }

  // Track when a conversation is opened (but don't mark as read yet)
  Future<void> trackConversationOpened(String conversationId) async {
    // This method doesn't change any read status
    // It can be used to track when a conversation is opened
    // For analytics or future features
  }

  // Get total unread count for admin
  Future<int> getAdminUnreadCount() async {
    try {
      // Query all conversations
      final querySnapshot =
          await _firestore.collection(_conversationsCollection).get();

      // Calculate total unread count for admin
      int totalUnread = 0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // First try to get from the unreadCounts map (newer format)
        if (data.containsKey('unreadCounts')) {
          final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
          if (unreadCounts != null && unreadCounts.containsKey('admin')) {
            totalUnread += (unreadCounts['admin'] as num).toInt();
          }
        }
        // Fallback to the old flag-based system
        else if (data.containsKey('unreadByAdmin') &&
            data['unreadByAdmin'] == true) {
          totalUnread += 1;
        }
      }

      if (kDebugMode) {
        print('Unread count for admin: $totalUnread');
      }

      return totalUnread;
    } catch (e) {
      // On error, return 0 to avoid blocking UI
      return 0;
    }
  }

  // Get total unread count for current reseller
  Future<int> getResellerUnreadCount() async {
    if (currentUserId == null) return 0;

    try {
      // Query conversations for this reseller
      final querySnapshot =
          await _firestore
              .collection(_conversationsCollection)
              .where('resellerId', isEqualTo: currentUserId)
              .get();

      // Calculate total unread count for reseller
      int totalUnread = 0;
      for (final doc in querySnapshot.docs) {
        final data = doc.data();

        // First try to get from the unreadCounts map (newer format)
        if (data.containsKey('unreadCounts')) {
          final unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
          if (unreadCounts != null && unreadCounts.containsKey(currentUserId)) {
            totalUnread += (unreadCounts[currentUserId] as num).toInt();
          }
        }
        // Fallback to the old flag-based system
        else if (data.containsKey('unreadByReseller') &&
            data['unreadByReseller'] == true) {
          totalUnread += 1;
        }
      }

      if (kDebugMode) {
        print('Unread count for reseller: $totalUnread');
      }

      return totalUnread;
    } catch (e) {
      // On error, return 0 to avoid blocking UI
      return 0;
    }
  }

  // Get unread messages count for the current user (admin or reseller)
  Stream<int> getUnreadMessagesCount() async* {
    final isAdmin = await isCurrentUserAdmin();

    if (isAdmin) {
      // Convert Future<int> to Stream<int>
      yield await getAdminUnreadCount();
    } else {
      // Convert Future<int> to Stream<int>
      yield await getResellerUnreadCount();
    }
  }

  // ---- NEW STREAM METHOD ----
  Stream<int> getUnreadMessagesCountStream() {
    final String? currentUserId = _auth.currentUser?.uid;
    // Determine the user ID field to check in unreadCounts
    // For resellers, it's their UID. For admin, it's the string 'admin'.
    // We need to know if the current user IS an admin first.

    // We can't directly call async `isCurrentUserAdmin` here.
    // One approach is to listen based on the known UID and assume non-admins are resellers.
    // A more robust approach might involve getting the role from an auth provider/state.
    // Assuming simple case: if currentUserId exists, check for that ID, otherwise maybe try 'admin'?
    // Let's refine this: We'll check the user's role AFTER getting the ID.

    if (currentUserId == null) {
      // If no user is logged in, return a stream of 0
      return Stream.value(0);
    }

    // First, get the user role. This requires an async call.
    // Since streams are synchronous in their definition, we use a Stream.fromFuture
    // combined with switchMap to transition from the Future<role> to the Stream<count>.
    return Stream.fromFuture(
          _firestore.collection('users').doc(currentUserId).get(),
        )
        .asyncMap((userDoc) async {
          // Determine the key to use based on the user's role
          final userData = userDoc.exists ? userDoc.data() : null;
          final role =
              userData?['role'] as String? ??
              'reseller'; // Default to reseller if role missing
          final String countKey =
              (role.toLowerCase() == 'admin') ? 'admin' : currentUserId;
          final bool isAdmin = (role.toLowerCase() == 'admin');
          // Use a simple Map or a custom class for clarity
          return {'countKey': countKey, 'isAdmin': isAdmin};
        })
        .switchMap((userData) {
          // <-- Use rxdart's switchMap extension method
          final String countKey = userData['countKey']! as String;
          final bool isAdmin = userData['isAdmin']! as bool;

          // Now that we have the key ('admin' or userId) and isAdmin flag, set up the Firestore listener
          Query query = _firestore.collection(_conversationsCollection);

          if (!isAdmin) {
            // Resellers only see their own conversations
            query = query.where('participants', arrayContains: currentUserId);
          }
          // Admins see all conversations (no extra where clause needed)

          return query.snapshots().map((snapshot) {
            int totalUnread = 0;
            for (final doc in snapshot.docs) {
              final data =
                  doc.data() as Map<String, dynamic>?; // Cast for safety
              if (data != null && data.containsKey('unreadCounts')) {
                final unreadCounts =
                    data['unreadCounts'] as Map<String, dynamic>?;
                if (unreadCounts != null &&
                    unreadCounts.containsKey(countKey)) {
                  // Safely convert to int, defaulting to 0 if null or wrong type
                  final count = unreadCounts[countKey];
                  if (count is num) {
                    totalUnread += count.toInt();
                  }
                }
              }
              // We ignore the old unreadByAdmin/unreadByReseller fields for the stream
            }
            if (kDebugMode) {
              print('Stream update: Total unread for $countKey: $totalUnread');
            }
            return totalUnread;
          });
        })
        .handleError((error) {
          // Log error and return 0 count on stream error
          if (kDebugMode) {
            print('Error in getUnreadMessagesCountStream: $error');
          }
          return 0;
        });
  }
  // ---- END NEW STREAM METHOD ----

  // Send a text message
  Future<void> sendTextMessage(String conversationId, String content) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Validate content length
    if (content.isEmpty) {
      throw Exception('Message cannot be empty');
    }

    if (content.length > _maxMessageLength) {
      throw Exception(
        'Message exceeds maximum length of $_maxMessageLength characters',
      );
    }

    // Apply rate limiting
    if (!_checkRateLimit(currentUserId!)) {
      throw Exception(
        'Too many messages sent in a short period. Please wait a moment.',
      );
    }

    try {
      // Get user admin status and name
      final isAdmin = await isCurrentUserAdmin();
      final userName = await getCurrentUserName();

      // Create the message
      final message = ChatMessage(
        id: '', // Will be set by Firestore
        senderId: currentUserId!,
        senderName: userName,
        content: content,
        type: MessageType.text,
        timestamp: DateTime.now(), // Will be overwritten by server timestamp
        isAdmin: isAdmin,
      );

      // Record this message send time for rate limiting
      _recordMessageSend(currentUserId!);

      // Get conversation info
      final conversationDoc =
          await _firestore
              .collection(_conversationsCollection)
              .doc(conversationId)
              .get();

      if (!conversationDoc.exists) {
        throw Exception("Conversation not found");
      }

      final conversationData = conversationDoc.data()!;
      final List<dynamic> participants =
          conversationData['participants'] ??
          ['admin', conversationData['resellerId']];

      // Create a batch for better performance
      final batch = _firestore.batch();

      // Add message to the collection
      final messageRef =
          _firestore
              .collection(_conversationsCollection)
              .doc(conversationId)
              .collection(_messagesCollection)
              .doc(); // Generate a new document ID

      batch.set(messageRef, message.toMap());

      // Update conversation with last message info
      final conversationRef = _firestore
          .collection(_conversationsCollection)
          .doc(conversationId);

      final updateData = <String, dynamic>{
        'lastMessageContent':
            content.length > 50
                ? '${content.substring(0, 50)}...'
                : content, // Truncate long messages in conversation list
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageIsFromAdmin': isAdmin,
      };

      // Determine recipient(s) to mark as having unread messages
      final String senderId = isAdmin ? 'admin' : currentUserId!;

      // Update unread counts for all participants except the sender
      for (final participantId in participants) {
        // Only increment unread count for participants who are not the sender
        if (participantId != senderId) {
          // --- REMOVE CLIENT-SIDE INCREMENT ---
          // Add to the unreadCounts map (KEEP THIS - although CF does it too, immediate feedback might be okay)
          // If experiencing issues, consider removing this client-side increment too.
          // updateData['unreadCounts.$participantId'] = FieldValue.increment(1);
          // --- END REMOVAL ---
        }
      }

      // Always mark conversation as active when sending a message
      // This ensures it will appear in the admin's list
      updateData['active'] = true;

      batch.update(conversationRef, updateData);

      // Commit all the changes at once
      await batch.commit();

      // Note: The conversation's 'active' state will be set by the Cloud Function trigger
    } catch (e) {
      if (kDebugMode) {
        print('Error sending text message: $e');
      }
      throw Exception('Failed to send message: $e');
    }
  }

  // Send an image message
  Future<void> sendImageMessage(
    String conversationId,
    dynamic imageFile,
  ) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Apply rate limiting
    if (!_checkRateLimit(currentUserId!)) {
      throw Exception(
        'Too many messages sent in a short period. Please wait a moment.',
      );
    }

    try {
      if (kDebugMode) {
        print('Starting image upload process');
        print('Image file type: ${imageFile.runtimeType}');
        print('Running on web: $kIsWeb');
      }

      // Generate a unique filename for the image
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${currentUserId!}';
      final storageRef = _storage.ref().child('chat_images/$fileName');

      String imageUrl;
      String? base64Data; // For web fallback

      // Handle different platform implementations for uploading images
      if (kIsWeb) {
        if (kDebugMode) {
          print('Processing image upload for web');
        }

        // For web, use a web-specific approach
        Uint8List? bytes;

        if (imageFile is XFile) {
          if (kDebugMode) {
            print('Image is XFile. Reading bytes...');
          }
          // If it's coming from image_picker as XFile, read bytes directly
          try {
            bytes = await imageFile.readAsBytes();
            if (kDebugMode) {
              print('Successfully read ${bytes.length} bytes from XFile');
            }
          } catch (e, stackTrace) {
            if (kDebugMode) {
              print('Error reading XFile bytes on web: $e');
              print(stackTrace);
            }
            throw Exception('Failed to read image from XFile on web: $e');
          }
        } else if (imageFile is io.File) {
          if (kDebugMode) {
            print('Image is io.File, attempting to read bytes');
          }
          try {
            // Try to read as bytes from File for web compatibility
            bytes = await imageFile.readAsBytes();
          } catch (e, stackTrace) {
            if (kDebugMode) {
              print('Error reading File bytes on web: $e');
              print(stackTrace);
            }
            throw Exception('Unable to read image file on web: $e');
          }
        } else if (imageFile is Uint8List) {
          if (kDebugMode) {
            print('Image is already Uint8List with ${imageFile.length} bytes');
          }
          // If bytes are already provided
          bytes = imageFile;
        } else {
          if (kDebugMode) {
            print('Unsupported image type: ${imageFile.runtimeType}');
          }
          throw Exception(
            'Unsupported image file format for web: ${imageFile.runtimeType}',
          );
        }

        // Ensure we have valid bytes before proceeding
        if (bytes.isEmpty) {
          throw Exception('Failed to read image data: Empty bytes');
        }

        // Create a base64 version for web fallback
        // Format with data URI prefix for direct usage
        final base64String = base64Encode(bytes);
        base64Data = 'data:image/jpeg;base64,$base64String';

        // Limit the length of base64 data to avoid hitting Firestore document size limits
        // Keep the first 100KB of base64 data which is enough for a small preview
        if (base64Data.length > 100000) {
          base64Data = base64Data.substring(0, 100000);
          if (kDebugMode) {
            print('Base64 data truncated to 100KB');
          }
        }

        // Attempt Firebase Storage upload
        imageUrl = await _uploadBytesToStorage(bytes, storageRef);

        // Create JSON with both URL and base64 data for web
        final contentJson = {'url': imageUrl, 'base64': base64Data};

        // Use the JSON as the message content
        final messageContent = json.encode(contentJson);

        // Send the message with the JSON content
        await _sendImageMessageToFirestore(conversationId, messageContent);
      } else {
        // For mobile platforms
        if (imageFile is XFile) {
          if (kDebugMode) {
            print('Image is XFile, path: ${imageFile.path}');
          }
          // Convert XFile to io.File for mobile
          try {
            final file = io.File(imageFile.path);
            if (await file.exists()) {
              if (kDebugMode) {
                print('File exists at path: ${file.path}');
              }
              imageUrl = await _uploadFileToStorage(file, storageRef);
              // Send the message with URL only
              await _sendImageMessageToFirestore(conversationId, imageUrl);
            } else {
              if (kDebugMode) {
                print('File does not exist at path: ${file.path}');
              }
              throw Exception(
                'Image file does not exist at path: ${imageFile.path}',
              );
            }
          } catch (e, stackTrace) {
            if (kDebugMode) {
              print('Error converting XFile to File: $e');
              print(stackTrace);
            }
            throw Exception('Failed to process XFile on mobile: $e');
          }
        } else if (imageFile is io.File) {
          if (kDebugMode) {
            print('Image is io.File, path: ${imageFile.path}');
          }
          if (await imageFile.exists()) {
            // Upload a native File directly
            imageUrl = await _uploadFileToStorage(imageFile, storageRef);
            // Send the message with URL only
            await _sendImageMessageToFirestore(conversationId, imageUrl);
          } else {
            if (kDebugMode) {
              print('File does not exist at path: ${imageFile.path}');
            }
            throw Exception(
              'Image file does not exist at path: ${imageFile.path}',
            );
          }
        } else {
          if (kDebugMode) {
            print('Unsupported image type: ${imageFile.runtimeType}');
          }
          throw Exception(
            'Unsupported image file format: ${imageFile.runtimeType}',
          );
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Error in sendImageMessage: $e');
        print(stackTrace);
      }
      throw Exception('Failed to send image message: $e');
    }
  }

  // Helper method to send the image message to Firestore
  Future<void> _sendImageMessageToFirestore(
    String conversationId,
    String content,
  ) async {
    final isAdmin = await isCurrentUserAdmin();
    final userName = await getCurrentUserName();

    // Create the message
    final message = ChatMessage(
      id: '', // Will be set by Firestore
      senderId: currentUserId!,
      senderName: userName,
      content: content,
      type: MessageType.image,
      timestamp: DateTime.now(), // Will be overwritten by server timestamp
      isAdmin: isAdmin,
    );

    // Record this message send time for rate limiting
    _recordMessageSend(currentUserId!);

    try {
      // Get conversation info
      final conversationDoc =
          await _firestore
              .collection(_conversationsCollection)
              .doc(conversationId)
              .get();

      if (!conversationDoc.exists) {
        throw Exception("Conversation not found");
      }

      final conversationData = conversationDoc.data()!;
      final List<dynamic> participants =
          conversationData['participants'] ??
          ['admin', conversationData['resellerId']];

      // Create a batch for better performance
      final batch = _firestore.batch();

      // Add message to the collection
      final messageRef =
          _firestore
              .collection(_conversationsCollection)
              .doc(conversationId)
              .collection(_messagesCollection)
              .doc(); // Generate a new document ID

      batch.set(messageRef, message.toMap());

      // Update conversation with last message info
      final conversationRef = _firestore
          .collection(_conversationsCollection)
          .doc(conversationId);

      final updateData = <String, dynamic>{
        'lastMessageContent':
            '[Image]', // Just show [Image] in the conversation list
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageIsFromAdmin': isAdmin,
      };

      // Determine recipient(s) to mark as having unread messages
      final String senderId = isAdmin ? 'admin' : currentUserId!;

      // Update unread counts for all participants except the sender
      for (final participantId in participants) {
        // Only increment unread count for participants who are not the sender
        if (participantId != senderId) {
          // --- REMOVE CLIENT-SIDE INCREMENT ---
          // Add to the unreadCounts map
          // updateData['unreadCounts.$participantId'] = FieldValue.increment(1);
          // --- END REMOVAL ---
        }
      }

      // Always mark conversation as active when sending an image
      // This ensures it will appear in the admin's list
      updateData['active'] = true;

      batch.update(conversationRef, updateData);

      // Commit all the changes at once
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error sending image message to Firestore: $e');
      }
      throw Exception('Failed to save image message: $e');
    }
  }

  // Helper method for web to upload bytes
  Future<String> _uploadBytesToStorage(
    Uint8List bytes,
    Reference storageRef,
  ) async {
    try {
      if (kDebugMode) {
        print('Starting _uploadBytesToStorage with ${bytes.length} bytes');
      }

      // Check file size
      if (bytes.length > _maxImageSizeMB * 1024 * 1024) {
        throw Exception('Image size exceeds maximum of $_maxImageSizeMB MB');
      }

      if (kDebugMode) {
        print('Creating upload task with Firebase Storage...');
      }

      // Create metadata with proper content type and fix for CORS
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploaded-from': 'web-app'},
      );

      // Upload bytes
      final uploadTask = storageRef.putData(bytes, metadata);

      if (kDebugMode) {
        print('Upload task created, waiting for completion...');
      }

      // Set up error handling and timeouts
      bool isComplete = false;
      Exception? timeoutException;

      // Add timeout handling
      Future.delayed(const Duration(seconds: 30), () {
        if (!isComplete) {
          timeoutException = Exception('Upload timed out after 30 seconds');
          if (kDebugMode) {
            print('Upload timeout occurred');
          }
        }
      });

      // Monitor progress for debugging
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (kDebugMode) {
            print(
              'Upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes',
            );
            print('Upload state: ${snapshot.state}');
          }
        },
        onError: (e) {
          if (kDebugMode) {
            print('Error during upload stream: $e');
          }
        },
      );

      // Wait for completion with timeout check
      TaskSnapshot? snapshot;
      try {
        snapshot = await uploadTask;
        isComplete = true;

        // Check if a timeout occurred during the wait
        if (timeoutException != null) {
          throw timeoutException!;
        }

        if (kDebugMode) {
          print('Upload complete, getting download URL...');
        }
      } catch (e) {
        isComplete = true;
        if (kDebugMode) {
          print('Error during await uploadTask: $e');
        }
        rethrow;
      }

      // Try to get download URL with retry logic
      String? downloadUrl;
      int retries = 3;
      while (retries > 0 && downloadUrl == null) {
        try {
          downloadUrl = await snapshot.ref.getDownloadURL();
          if (kDebugMode) {
            print('Successfully got download URL: $downloadUrl');
          }
        } catch (e) {
          retries--;
          if (kDebugMode) {
            print('Failed to get download URL, retries left: $retries');
            print('Error: $e');
          }
          if (retries > 0) {
            // Wait before retry
            await Future.delayed(const Duration(seconds: 1));
          } else {
            rethrow;
          }
        }
      }

      return downloadUrl!;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Web image upload error: $e');
        print(stackTrace);
        print(
          'Checking Firebase Storage permissions and CORS configuration...',
        );

        // Check authentication state
        final user = _auth.currentUser;
        print(
          'User is ${user != null ? "authenticated" : "not authenticated"}',
        );
        if (user != null) {
          print('User ID: ${user.uid}');
        }
      }
      throw Exception('Failed to upload image bytes: $e');
    }
  }

  // Helper method for mobile to upload file
  Future<String> _uploadFileToStorage(
    io.File file,
    Reference storageRef,
  ) async {
    try {
      if (kDebugMode) {
        print('Starting _uploadFileToStorage with file path: ${file.path}');
      }

      // Check file size
      final fileSize = await file.length();
      if (kDebugMode) {
        print('File size: $fileSize bytes');
      }

      if (fileSize > _maxImageSizeMB * 1024 * 1024) {
        throw Exception('Image size exceeds maximum of $_maxImageSizeMB MB');
      }

      if (kDebugMode) {
        print('Creating upload task with Firebase Storage...');
      }

      // Upload file
      final uploadTask = storageRef.putFile(file);

      if (kDebugMode) {
        print('Upload task created, waiting for completion...');
      }

      final snapshot = await uploadTask;

      if (kDebugMode) {
        print('Upload complete, getting download URL...');
      }

      // Return download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        print('Successfully got download URL: $downloadUrl');
      }

      return downloadUrl;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('Native image upload error: $e');
        print(stackTrace);
      }
      throw Exception('Failed to upload image file: $e');
    }
  }

  // Helper method for rate limiting
  bool _checkRateLimit(String userId) {
    final now = DateTime.now();

    // Initialize if this is the first message from this user
    if (!_messageSendTimes.containsKey(userId)) {
      _messageSendTimes[userId] = [];
      return true;
    }

    // Remove timestamps older than 1 minute
    _messageSendTimes[userId]!.removeWhere(
      (timestamp) => now.difference(timestamp).inMinutes >= 1,
    );

    // Check if user has exceeded the rate limit
    return _messageSendTimes[userId]!.length < _messageRateLimitPerMinute;
  }

  // Record message send time for rate limiting
  void _recordMessageSend(String userId) {
    if (!_messageSendTimes.containsKey(userId)) {
      _messageSendTimes[userId] = [];
    }

    _messageSendTimes[userId]!.add(DateTime.now());
  }

  // Track when a user is active in a conversation
  Future<void> setUserActiveInConversation(
    String conversationId,
    bool isActive,
  ) async {
    if (currentUserId == null) return;

    try {
      // ---> ADD LOGS START <---
      print('--- setUserActive START ---');
      print('Conversation ID: $conversationId');
      print('IsActive flag: $isActive');
      final bool isAdmin = await isCurrentUserAdmin();
      final String userActiveId = isAdmin ? 'admin' : currentUserId!;
      print('Determined userActiveId: $userActiveId (isAdmin: $isAdmin)');
      // ---> ADD LOGS END <---

      // Use atomic operations
      final updateData = {
        'activeUsers':
            isActive
                ? FieldValue.arrayUnion([userActiveId]) // Atomically add
                : FieldValue.arrayRemove([userActiveId]), // Atomically remove
      };

      print(
        '--- Attempting Firestore update: ${isActive ? 'arrayUnion' : 'arrayRemove'} ---',
      ); // <-- ADD THIS
      await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .update(updateData); // Apply atomic update

      if (kDebugMode) {
        // print(
        //     'Applied ${isActive ? 'arrayUnion' : 'arrayRemove'} for $userActiveId'); // Old log
        print(
          '--- Firestore update SUCCEEDED: Applied ${isActive ? 'arrayUnion' : 'arrayRemove'} for $userActiveId ---',
        ); // Modified log
      }
    } catch (e) {
      if (kDebugMode) {
        // print('Error setting user active status: $e'); // Old log
        print(
          '--- setUserActive: ERROR during Firestore update: $e ---',
        ); // Modified log
      }
      // Don't throw the error to prevent UI disruption
    } finally {
      // <-- ADD FINALLY BLOCK
      print('--- setUserActive END ---');
    }
  }

  /// Reset a conversation by clearing all messages
  /// This is an admin-only operation
  Future<void> resetConversation(String conversationId) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Check if user is admin
    final isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) {
      throw Exception('Only admins can reset conversations');
    }

    try {
      // Call the resetConversation Firebase function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('resetConversation');

      final result = await callable.call({'conversationId': conversationId});

      if (kDebugMode) {
        print('Reset conversation result: ${result.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting conversation: $e');
      }
      throw Exception('Failed to reset conversation: $e');
    }
  }

  /// Get a list of all inactive conversations (admin only)
  Future<List<ChatConversation>> getInactiveConversations() async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Check if user is admin
    final isAdmin = await isCurrentUserAdmin();
    if (!isAdmin) {
      throw Exception('Only admins can view inactive conversations');
    }

    try {
      // Call the getInactiveConversations Firebase function
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('getInactiveConversations');

      final result = await callable.call({});

      if (kDebugMode) {
        print('Get inactive conversations result: ${result.data}');
      }

      // Parse the result data
      final List<dynamic> inactiveConversationsData =
          result.data['inactiveConversations'] ?? [];

      // Convert to ChatConversation objects
      final List<ChatConversation> inactiveConversations = [];

      for (final data in inactiveConversationsData) {
        final conversationId = data['conversationId'] as String;

        // Fetch the full conversation document for complete data
        final conversationDoc =
            await _firestore
                .collection(_conversationsCollection)
                .doc(conversationId)
                .get();

        if (conversationDoc.exists) {
          inactiveConversations.add(
            ChatConversation.fromFirestore(conversationDoc),
          );
        }
      }

      return inactiveConversations;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting inactive conversations: $e');
      }
      throw Exception('Failed to get inactive conversations: $e');
    }
  }

  // Send a file message
  Future<void> sendFileMessage(
    String conversationId,
    dynamic file,
    String fileName,
    String fileType,
    int fileSize,
  ) async {
    if (currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // Validate file size
    if (fileSize > _maxFileSizeMB * 1024 * 1024) {
      throw Exception(
        'File exceeds maximum size of $_maxFileSizeMB MB',
      );
    }

    // Apply rate limiting
    if (!_checkRateLimit(currentUserId!)) {
      throw Exception(
        'Too many messages sent in a short period. Please wait a moment.',
      );
    }

    try {
      // Get user admin status and name
      final isAdmin = await isCurrentUserAdmin();
      final userName = await getCurrentUserName();

      // Generate a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${timestamp}_$fileName';
      final storagePath = 'chat_files/$conversationId/$uniqueFileName';

      // Upload file to Firebase Storage
      final storageRef = _storage.ref().child(storagePath);
      UploadTask uploadTask;

      if (kIsWeb) {
        // Web platform
        final bytes = await file.bytes;
        uploadTask = storageRef.putData(bytes);
      } else {
        // Mobile platform
        uploadTask = storageRef.putFile(io.File(file.path));
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Create the message
      final message = ChatMessage(
        id: '', // Will be set by Firestore
        senderId: currentUserId!,
        senderName: userName,
        content: downloadUrl,
        type: MessageType.file,
        timestamp: DateTime.now(), // Will be overwritten by server timestamp
        isAdmin: isAdmin,
        fileName: fileName,
        fileType: fileType,
        fileSize: fileSize,
      );

      // Record this message send time for rate limiting
      _recordMessageSend(currentUserId!);

      // Get conversation info
      final conversationDoc = await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        throw Exception("Conversation not found");
      }

      final conversationData = conversationDoc.data()!;
      final List<dynamic> participants =
          conversationData['participants'] ??
          ['admin', conversationData['resellerId']];

      // Create a batch for better performance
      final batch = _firestore.batch();

      // Add message to the collection
      final messageRef = _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .doc(); // Generate a new document ID

      batch.set(messageRef, message.toMap());

      // Update conversation with last message info
      final conversationRef = _firestore
          .collection(_conversationsCollection)
          .doc(conversationId);

      final updateData = <String, dynamic>{
        'lastMessageContent': '📎 ${fileName}',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageIsFromAdmin': isAdmin,
      };

      // Determine recipient(s) to mark as having unread messages
      final String senderId = isAdmin ? 'admin' : currentUserId!;

      // Update unread counts for all participants except the sender
      for (final participantId in participants) {
        // Only increment unread count for participants who are not the sender
        if (participantId != senderId) {
          // Add to the unreadCounts map
          updateData['unreadCounts.$participantId'] = FieldValue.increment(1);
        }
      }

      // Always mark conversation as active when sending a message
      updateData['active'] = true;

      batch.update(conversationRef, updateData);

      // Commit all the changes at once
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print('Error sending file message: $e');
      }
      throw Exception('Failed to send file: $e');
    }
  }
}
