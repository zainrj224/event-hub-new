import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Handles follow/unfollow between users and notification dispatch.
/// 
/// Firestore structure:
///   follows/{followerId}_{followedId}  { followerId, followedId, createdAt }
///   notifications/{autoId}             { toUserId, fromUserId, fromName, fromAvatar, message, read, createdAt }
class FollowService {
  static final FollowService instance = FollowService._();
  FollowService._();

  final _db = FirebaseFirestore.instance;

  String _docId(String followerId, String followedId) =>
      '${followerId}_$followedId';

  /// Whether [currentUserId] follows [targetUserId]
  Stream<bool> isFollowingStream(String targetUserId) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return Stream.value(false);
    return _db
        .collection('follows')
        .doc(_docId(me, targetUserId))
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Follower count for [userId]
  Stream<int> followerCountStream(String userId) {
    return _db
        .collection('follows')
        .where('followedId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Follow [targetUserId] and send them a notification.
  Future<void> follow(String targetUserId, {
    required String targetName,
    required String targetAvatar,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid == targetUserId) return;

    final batch = _db.batch();
    final followRef = _db.collection('follows').doc(_docId(me.uid, targetUserId));
    final notifRef = _db.collection('notifications').doc();

    batch.set(followRef, {
      'followerId': me.uid,
      'followedId': targetUserId,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    batch.set(notifRef, {
      'toUserId': targetUserId,
      'fromUserId': me.uid,
      'fromName': me.displayName ?? me.email ?? 'Someone',
      'fromAvatar': me.photoURL ?? '',
      'message': 'started following you',
      'type': 'follow',
      'read': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    await batch.commit();
  }

  /// Unfollow [targetUserId].
  Future<void> unfollow(String targetUserId) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    await _db.collection('follows').doc(_docId(me.uid, targetUserId)).delete();
  }

  /// Called when a host creates/updates an event — notifies all followers.
  static Future<void> notifyFollowersOfNewEvent({
    required String hostId,
    required String hostName,
    required String hostAvatar,
    required String eventTitle,
    required String eventId,
  }) async {
    final db = FirebaseFirestore.instance;
    // Get all followers of this host
    final followsSnap = await db
        .collection('follows')
        .where('followedId', isEqualTo: hostId)
        .get();

    if (followsSnap.docs.isEmpty) return;

    final batch = db.batch();
    for (final doc in followsSnap.docs) {
      final followerId = doc.data()['followerId'] as String;
      final notifRef = db.collection('notifications').doc();
      batch.set(notifRef, {
        'toUserId': followerId,
        'fromUserId': hostId,
        'fromName': hostName,
        'fromAvatar': hostAvatar,
        'message': 'posted a new event: "$eventTitle"',
        'type': 'new_event',
        'eventId': eventId,
        'read': false,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    await batch.commit();
  }
}
