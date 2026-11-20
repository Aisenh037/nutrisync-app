import 'package:cloud_firestore/cloud_firestore.dart';

/// A single conversation turn (user or assistant).
class ConversationTurn {
  const ConversationTurn({
    required this.role,
    required this.text,
    required this.timestamp,
    this.interactionType,
    this.sessionId,
  });

  /// Either 'user' or 'assistant'.
  final String role;
  final String text;
  final DateTime timestamp;
  final String? interactionType;
  final String? sessionId;

  Map<String, dynamic> toMap() => {
        'role': role,
        'text': text,
        'timestamp': Timestamp.fromDate(timestamp),
        if (interactionType != null) 'interactionType': interactionType,
        if (sessionId != null) 'sessionId': sessionId,
      };

  factory ConversationTurn.fromMap(Map<String, dynamic> map) =>
      ConversationTurn(
        role: map['role'] as String,
        text: map['text'] as String,
        timestamp: (map['timestamp'] as Timestamp).toDate(),
        interactionType: map['interactionType'] as String?,
        sessionId: map['sessionId'] as String?,
      );

  bool get isUser => role == 'user';
}

/// Firestore-backed conversation history store.
///
/// Structure:
///   users/{uid}/conversation_turns/{turnId}  →  ConversationTurn
///
/// Each turn is a top-level document ordered by `timestamp`.
/// Keeps the last [_maxTurns] turns per user to bound storage and token cost.
class ConversationMemoryService {
  ConversationMemoryService._();
  static final ConversationMemoryService instance =
      ConversationMemoryService._();

  static const int _maxTurns = 40;
  static const int _loadLimit = 20; // turns loaded for context injection

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _turns(String uid) =>
      _db.collection('users').doc(uid).collection('conversation_turns');

  // ── Write ───────────────────────────────────────────────────────────────────

  /// Saves a user or assistant turn.  Silently no-ops on error — conversation
  /// should never be blocked by a storage failure.
  Future<void> saveTurn({
    required String userId,
    required String role,
    required String text,
    String? sessionId,
    String? interactionType,
  }) async {
    if (text.trim().isEmpty) return;
    try {
      await _turns(userId).add(
        ConversationTurn(
          role: role,
          text: text,
          timestamp: DateTime.now(),
          sessionId: sessionId,
          interactionType: interactionType,
        ).toMap(),
      );
      _pruneIfNeeded(userId); // fire-and-forget
    } catch (_) {
      // non-fatal
    }
  }

  Future<void> clearHistory(String userId) async {
    try {
      final snap = await _turns(userId).get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  /// Returns up to [_loadLimit] most-recent turns, oldest-first (chat order).
  Future<List<ConversationTurn>> loadHistory(String userId) async {
    try {
      final snap = await _turns(userId)
          .orderBy('timestamp', descending: true)
          .limit(_loadLimit)
          .get();
      return snap.docs
          .map((d) => ConversationTurn.fromMap(d.data()))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Live stream of new turns added after [since] (for real-time UI updates).
  Stream<ConversationTurn> watchNewTurns(String userId, DateTime since) {
    return _turns(userId)
        .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('timestamp')
        .snapshots()
        .expand((snap) => snap.docChanges
            .where((c) => c.type == DocumentChangeType.added)
            .map((c) => ConversationTurn.fromMap(c.doc.data()!)));
  }

  // ── Prune ───────────────────────────────────────────────────────────────────

  Future<void> _pruneIfNeeded(String userId) async {
    try {
      final count =
          await _turns(userId).count().get().then((s) => s.count ?? 0);
      if (count <= _maxTurns) return;

      // Delete oldest (count - _maxTurns) documents
      final excess = count - _maxTurns;
      final old = await _turns(userId)
          .orderBy('timestamp')
          .limit(excess)
          .get();
      final batch = _db.batch();
      for (final doc in old.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }
}
