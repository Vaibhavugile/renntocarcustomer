import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIConversationService {
  AIConversationService._();

  static final AIConversationService instance =
      AIConversationService._();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ------------------------------------------------------------
  // CURRENT USER
  // ------------------------------------------------------------

  String get currentUid {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    return user.uid;
  }

  // ------------------------------------------------------------
  // CONVERSATIONS REFERENCE
  // ------------------------------------------------------------

  CollectionReference<Map<String, dynamic>>
      _conversationCollection(
    String tenantId,
  ) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('customers')
        .doc(currentUid)
        .collection('aiConversations');
  }

  // ------------------------------------------------------------
  // CREATE CONVERSATION
  // ------------------------------------------------------------

  Future<String> createConversation({
    required String tenantId,
  }) async {
    final ref =
        _conversationCollection(tenantId).doc();

    await ref.set({
      'conversationId': ref.id,
      'tenantId': tenantId,
      'customerId': currentUid,
      'title': 'New conversation',
      'status': 'active',
      'createdAt':
          FieldValue.serverTimestamp(),
      'updatedAt':
          FieldValue.serverTimestamp(),
      'lastMessage': null,
      'lastMessageAt': null,
      'messageCount': 0,
    });

    return ref.id;
  }

  // ------------------------------------------------------------
  // GET OR CREATE CONVERSATION
  // ------------------------------------------------------------

  Future<String> getOrCreateConversation({
    required String tenantId,
    String? conversationId,
  }) async {
    if (conversationId != null &&
        conversationId.trim().isNotEmpty) {
      final id = conversationId.trim();

      final ref =
          _conversationCollection(tenantId).doc(id);

      final snapshot = await ref.get();

      if (snapshot.exists) {
        return id;
      }
    }

    return createConversation(
      tenantId: tenantId,
    );
  }

  // ------------------------------------------------------------
  // SAVE USER MESSAGE
  // ------------------------------------------------------------

  Future<String> saveUserMessage({
    required String tenantId,
    required String conversationId,
    required String content,
  }) async {
    return _saveMessage(
      tenantId: tenantId,
      conversationId: conversationId,
      role: AIMessageRole.user,
      content: content,
    );
  }

  // ------------------------------------------------------------
  // SAVE ASSISTANT MESSAGE
  // ------------------------------------------------------------

  Future<String> saveAssistantMessage({
    required String tenantId,
    required String conversationId,
    required String content,
  }) async {
    return _saveMessage(
      tenantId: tenantId,
      conversationId: conversationId,
      role: AIMessageRole.assistant,
      content: content,
    );
  }

  // ------------------------------------------------------------
  // INTERNAL SAVE MESSAGE
  // ------------------------------------------------------------

  Future<String> _saveMessage({
    required String tenantId,
    required String conversationId,
    required String role,
    required String content,
  }) async {
    final conversationRef =
        _conversationCollection(tenantId)
            .doc(conversationId);

    final messageRef =
        conversationRef.collection('messages').doc();

    final cleanContent = content.trim();

    await messageRef.set({
      'messageId': messageRef.id,
      'conversationId': conversationId,
      'customerId': currentUid,
      'tenantId': tenantId,
      'role': role,
      'content': cleanContent,
      'createdAt':
          FieldValue.serverTimestamp(),
    });

    await conversationRef.set(
      {
        'updatedAt':
            FieldValue.serverTimestamp(),
        'lastMessage': cleanContent,
        'lastMessageRole': role,
        'lastMessageAt':
            FieldValue.serverTimestamp(),
        'messageCount':
            FieldValue.increment(1),
      },
      SetOptions(merge: true),
    );

    return messageRef.id;
  }

  // ------------------------------------------------------------
  // LOAD CONVERSATION
  // ------------------------------------------------------------

  Future<AIConversation?> getConversation({
    required String tenantId,
    required String conversationId,
  }) async {
    final snapshot =
        await _conversationCollection(tenantId)
            .doc(conversationId)
            .get();

    if (!snapshot.exists) {
      return null;
    }

    return AIConversation.fromFirestore(
      snapshot,
    );
  }

  // ------------------------------------------------------------
  // LOAD MESSAGES
  // ------------------------------------------------------------

  Future<List<AIMessage>> getMessages({
    required String tenantId,
    required String conversationId,
    int limit = 100,
  }) async {
    final safeLimit =
        limit.clamp(1, 200);

    final snapshot =
        await _conversationCollection(tenantId)
            .doc(conversationId)
            .collection('messages')
            .orderBy(
              'createdAt',
              descending: false,
            )
            .limit(safeLimit)
            .get();

    return snapshot.docs
        .map(
          AIMessage.fromFirestore,
        )
        .toList();
  }

  // ------------------------------------------------------------
  // STREAM MESSAGES
  // ------------------------------------------------------------

  Stream<List<AIMessage>> messagesStream({
    required String tenantId,
    required String conversationId,
    int limit = 100,
  }) {
    final safeLimit =
        limit.clamp(1, 200);

    return _conversationCollection(tenantId)
        .doc(conversationId)
        .collection('messages')
        .orderBy(
          'createdAt',
          descending: false,
        )
        .limit(safeLimit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                AIMessage.fromFirestore,
              )
              .toList(),
        );
  }

  // ------------------------------------------------------------
  // LOAD CONVERSATIONS
  // ------------------------------------------------------------

  Future<List<AIConversation>>
      getConversations({
    required String tenantId,
    int limit = 50,
  }) async {
    final safeLimit =
        limit.clamp(1, 100);

    final snapshot =
        await _conversationCollection(tenantId)
            .orderBy(
              'updatedAt',
              descending: true,
            )
            .limit(safeLimit)
            .get();

    return snapshot.docs
        .map(
          AIConversation.fromFirestore,
        )
        .toList();
  }

  // ------------------------------------------------------------
  // DELETE CONVERSATION
  // ------------------------------------------------------------

  Future<void> deleteConversation({
    required String tenantId,
    required String conversationId,
  }) async {
    final conversationRef =
        _conversationCollection(tenantId)
            .doc(conversationId);

    final messages =
        await conversationRef
            .collection('messages')
            .get();

    final batch =
        _firestore.batch();

    for (final doc in messages.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(conversationRef);

    await batch.commit();
  }

  // ------------------------------------------------------------
  // RENAME CONVERSATION
  // ------------------------------------------------------------

  Future<void> renameConversation({
    required String tenantId,
    required String conversationId,
    required String title,
  }) async {
    final cleanTitle =
        title.trim();

    if (cleanTitle.isEmpty) {
      return;
    }

    await _conversationCollection(tenantId)
        .doc(conversationId)
        .set(
      {
        'title': cleanTitle,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ------------------------------------------------------------
  // UPDATE CONVERSATION STATE
  // ------------------------------------------------------------

  Future<void> updateConversationState({
    required String tenantId,
    required String conversationId,
    required Map<String, dynamic> state,
  }) async {
    await _conversationCollection(tenantId)
        .doc(conversationId)
        .set(
      {
        'conversationState': state,
        'updatedAt':
            FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  // ------------------------------------------------------------
  // GET CONVERSATION STATE
  // ------------------------------------------------------------

  Future<Map<String, dynamic>>
      getConversationState({
    required String tenantId,
    required String conversationId,
  }) async {
    final snapshot =
        await _conversationCollection(tenantId)
            .doc(conversationId)
            .get();

    if (!snapshot.exists) {
      return {};
    }

    final data =
        snapshot.data() ?? {};

    final state =
        data['conversationState'];

    if (state is Map) {
      return Map<String, dynamic>.from(
        state,
      );
    }

    return {};
  }
}

// ============================================================
// MESSAGE ROLE
// ============================================================

class AIMessageRole {
  static const String user = 'user';
  static const String assistant = 'assistant';
  static const String system = 'system';
  static const String tool = 'tool';

  AIMessageRole._();
}

// ============================================================
// AI MESSAGE
// ============================================================

class AIMessage {
  final String id;
  final String role;
  final String content;
  final DateTime? createdAt;

  AIMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  factory AIMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>>
        snapshot,
  ) {
    final data =
        snapshot.data() ?? {};

    final timestamp =
        data['createdAt'];

    return AIMessage(
      id: snapshot.id,
      role:
          data['role']?.toString() ??
              AIMessageRole.assistant,
      content:
          data['content']?.toString() ??
              '',
      createdAt:
          timestamp is Timestamp
              ? timestamp.toDate()
              : null,
    );
  }

  bool get isUser =>
      role == AIMessageRole.user;

  bool get isAssistant =>
      role == AIMessageRole.assistant;
}

// ============================================================
// AI CONVERSATION
// ============================================================

class AIConversation {
  final String id;
  final String tenantId;
  final String customerId;
  final String title;
  final String status;
  final String? lastMessage;
  final String? lastMessageRole;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;
  final int messageCount;
  final Map<String, dynamic> conversationState;

  AIConversation({
    required this.id,
    required this.tenantId,
    required this.customerId,
    required this.title,
    required this.status,
    this.lastMessage,
    this.lastMessageRole,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
    this.messageCount = 0,
    this.conversationState = const {},
  });

  factory AIConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>>
        snapshot,
  ) {
    final data =
        snapshot.data() ?? {};

    final state =
        data['conversationState'];

    return AIConversation(
      id: snapshot.id,
      tenantId:
          data['tenantId']?.toString() ??
              '',
      customerId:
          data['customerId']?.toString() ??
              '',
      title:
          data['title']?.toString() ??
              'AI Assistant',
      status:
          data['status']?.toString() ??
              'active',
      lastMessage:
          data['lastMessage']?.toString(),
      lastMessageRole:
          data['lastMessageRole']?.toString(),
      createdAt:
          _timestampToDate(
        data['createdAt'],
      ),
      updatedAt:
          _timestampToDate(
        data['updatedAt'],
      ),
      lastMessageAt:
          _timestampToDate(
        data['lastMessageAt'],
      ),
      messageCount:
          _toInt(
        data['messageCount'],
      ),
      conversationState:
          state is Map
              ? Map<String, dynamic>.from(
                  state,
                )
              : const {},
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

DateTime? _timestampToDate(
  dynamic value,
) {
  if (value is Timestamp) {
    return value.toDate();
  }

  return null;
}

int _toInt(
  dynamic value,
) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      0;
}
