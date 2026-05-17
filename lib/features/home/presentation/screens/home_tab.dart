import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/events/domain/entities/event_entity.dart';
import '../../../../features/events/data/models/event_model.dart';
import '../../../../features/events/presentation/widgets/event_card.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Event> _events = [];
  bool _loading = true;
  String? _error;
  List<String> _followedIds = []; // hostIds of people I follow
  StreamSubscription? _followsSub;
  StreamSubscription? _eventsSub;

  // For avatar — read base64 from Firestore
  String? _photoBase64;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _subscribeFollows();
  }

  @override
  void dispose() {
    _followsSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(uid).get();
      final b64 = doc.data()?['photoBase64'] as String?;
      if (b64 != null && mounted) setState(() => _photoBase64 = b64);
    } catch (_) {}
  }

  /// Step 1: listen to who I follow → get their user IDs
  void _subscribeFollows() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() { _loading = false; });
      return;
    }

    _followsSub?.cancel();
    _followsSub = FirebaseFirestore.instance
        .collection('follows')
        .where('followerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final ids = snap.docs
          .map((d) => d.data()['followedId'] as String)
          .toList();
      if (mounted) {
        setState(() => _followedIds = ids);
        _subscribeEvents(ids);
      }
    }, onError: (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    });
  }

  /// Step 2: listen to events from followed users
  void _subscribeEvents(List<String> followedIds) {
    _eventsSub?.cancel();

    if (followedIds.isEmpty) {
      if (mounted) setState(() { _events = []; _loading = false; _error = null; });
      return;
    }

    setState(() { _loading = true; _error = null; });

    // Firestore 'in' query supports max 30 items; slice if needed
    final ids = followedIds.take(30).toList();

    _eventsSub = FirebaseFirestore.instance
        .collection('events')
        .where('hostId', whereIn: ids)
        .snapshots()
        .listen((snap) {
      final events = snap.docs.map((doc) {
        try { return EventModel.fromFirestore(doc).toEntity(); }
        catch (_) { return null; }
      }).whereType<Event>().toList();

      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() { _events = events; _loading = false; _error = null; });
      }
    }, onError: (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';
    final photoURL = user?.photoURL;
    final initial = (user?.displayName?.isNotEmpty == true
            ? user!.displayName![0]
            : user?.email?[0] ?? 'U')
        .toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [

            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hey, $name 👋',
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          _followedIds.isEmpty
                              ? 'Follow people to see their events'
                              : 'Events from people you follow',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),
                      ],
                    ),
                  ),
                  _NotificationBell(),
                  const SizedBox(width: 10),
                  _UserAvatar(
                    photoBase64: _photoBase64,
                    photoURL: photoURL,
                    initial: initial,
                  ),
                ]),
              ),
            ),

            // ── Search bar ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.search),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Row(children: [
                      SizedBox(width: 14),
                      Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                      SizedBox(width: 8),
                      Text('Search events...',
                          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
                    ]),
                  ),
                ),
              ),
            ),

            // ── Section label ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Following\'s Events',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    if (_followedIds.isNotEmpty)
                      Text('${_followedIds.length} following',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.purple)))

            else if (_error != null)
              SliverToBoxAdapter(
                  child: _EmptyState(
                      icon: Icons.error_outline,
                      title: 'Something went wrong',
                      subtitle: _error!))

            else if (_followedIds.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'Your feed is empty',
                  subtitle: 'Go to Explore, find events you like,\nand follow those hosts!',
                  actionLabel: 'Go to Explore',
                  onAction: () {
                    // Explore is a sibling tab in the bottom nav — just show a hint
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tap the Explore tab below to find events!'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              )

            else if (_events.isEmpty)
              SliverToBoxAdapter(
                  child: _EmptyState(
                      icon: Icons.event_busy_rounded,
                      title: 'No events yet',
                      subtitle: 'People you follow haven\'t posted any events yet.'))

            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: EventCard(
                        event: _events[i],
                        onTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.eventDetail, arguments: _events[i]),
                      ),
                    ),
                    childCount: _events.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Notification Bell ──────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snap) {
        final unread = snap.data?.docs.length ?? 0;
        return GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _NotificationsSheet(uid: uid),
          ),
          child: Stack(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.notifications_outlined,
                  color: Color(0xFF374151), size: 22),
            ),
            if (unread > 0)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEF4444), shape: BoxShape.circle),
                  child: Center(
                    child: Text(unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

// ── Notifications Sheet ────────────────────────────────────────────────────

class _NotificationsSheet extends StatelessWidget {
  final String uid;
  const _NotificationsSheet({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () => _markAllRead(),
                child: const Text('Mark all read',
                    style: TextStyle(color: AppColors.purple, fontSize: 13)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('toUserId', isEqualTo: uid)
                .limit(50)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(
                    color: AppColors.purple));
              }
              final rawDocs = snap.data?.docs ?? [];
              // Sort client-side by createdAt (int ms) — avoids composite index
              final docs = List.of(rawDocs)
                ..sort((a, b) {
                  final aT = (a.data() as Map)['createdAt'];
                  final bT = (b.data() as Map)['createdAt'];
                  final aMs = aT is int ? aT : (aT is Timestamp ? aT.millisecondsSinceEpoch : 0);
                  final bMs = bT is int ? bT : (bT is Timestamp ? bT.millisecondsSinceEpoch : 0);
                  return bMs.compareTo(aMs);
                });
              if (docs.isEmpty) {
                return const Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none_rounded,
                          size: 48, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(
                              color: Color(0xFF9CA3AF), fontSize: 15)),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final docId = docs[i].id;
                  final isRead = data['read'] == true;
                  final fromName = data['fromName'] as String? ?? 'Someone';
                  final fromAvatar = data['fromAvatar'] as String? ?? '';
                  final message = data['message'] as String? ?? '';
                  final ts = data['createdAt'];
                  DateTime? tsDate;
                  if (ts is Timestamp) tsDate = ts.toDate();
                  if (ts is int) tsDate = DateTime.fromMillisecondsSinceEpoch(ts);
                  final time = tsDate != null ? _timeAgo(tsDate) : '';

                  return InkWell(
                    onTap: () => FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(docId)
                        .update({'read': true}),
                    child: Container(
                      color: isRead ? Colors.white : const Color(0xFFF5F3FF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NotifAvatar(avatar: fromAvatar, name: fromName),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF111827)),
                                    children: [
                                      TextSpan(text: fromName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      TextSpan(text: ' $message'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(time,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF9CA3AF))),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8, height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                  color: AppColors.purple,
                                  shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Future<void> _markAllRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('toUserId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _NotifAvatar extends StatelessWidget {
  final String avatar;
  final String name;
  const _NotifAvatar({required this.avatar, required this.name});
  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    if (avatar.startsWith('data:')) {
      try {
        final bytes = base64Decode(avatar.split(',').last);
        return CircleAvatar(radius: 22, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    if (avatar.startsWith('http')) {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(avatar),
          onBackgroundImageError: (_, __) {});
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.purpleLight,
      child: Text(initial,
          style: const TextStyle(
              color: AppColors.purple, fontWeight: FontWeight.w700)),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String? photoBase64;
  final String? photoURL;
  final String initial;
  const _UserAvatar(
      {required this.photoBase64,
      required this.photoURL,
      required this.initial});
  @override
  Widget build(BuildContext context) {
    // Gallery upload (base64) takes priority
    if (photoBase64 != null && photoBase64!.startsWith('data:')) {
      try {
        final bytes = base64Decode(photoBase64!.split(',').last);
        return CircleAvatar(radius: 22, backgroundImage: MemoryImage(bytes));
      } catch (_) {}
    }
    if (photoURL != null &&
        photoURL!.startsWith('http') &&
        photoURL != 'profile_photo_in_firestore') {
      return CircleAvatar(radius: 22, backgroundImage: NetworkImage(photoURL!),
          onBackgroundImageError: (_, __) {});
    }
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.purpleLight,
      child: Text(initial,
          style: const TextStyle(
              color: AppColors.purple, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: AppColors.purpleLight, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.purple, size: 36),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
    );
  }
}
