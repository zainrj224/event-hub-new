import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../events/data/models/event_model.dart';

class SavedEventsScreen extends StatefulWidget {
  const SavedEventsScreen({super.key});

  @override
  State<SavedEventsScreen> createState() => _SavedEventsScreenState();
}

class _SavedEventsScreenState extends State<SavedEventsScreen> {
  StreamSubscription? _subscription;
  List<_SavedItem> _saved = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribe() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) { setState(() => _loading = false); return; }

    // NO orderBy — avoids composite index; sort in memory instead
    _subscription = FirebaseFirestore.instance
        .collection('savedEvents')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
      (snap) {
        final items = snap.docs.map((doc) {
          final d = doc.data();
          return _SavedItem(
            eventId: d['eventId'] ?? '',
            title: d['eventTitle'] ?? '',
            imageUrl: d['eventImage'] ?? '',
            location: d['eventLocation'] ?? '',
            category: d['eventCategory'] ?? '',
            hostName: d['hostName'] ?? '',
            hostAvatar: d['hostAvatar'] ?? '',
            hostId: d['hostId'] ?? '',
            dateStr: d['eventDate'] ?? '',
            savedAt: (d['savedAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
          );
        }).where((i) => i.eventId.isNotEmpty).toList();

        // Sort newest saved first — in memory, no index needed
        items.sort((a, b) => b.savedAt.compareTo(a.savedAt));

        if (mounted) setState(() { _saved = items; _loading = false; _error = null; });
      },
      onError: (e) {
        if (mounted) setState(() { _loading = false; _error = e.toString(); });
      },
    );
  }

  Future<void> _unsave(String userId, String eventId) async {
    try {
      await FirebaseFirestore.instance
          .collection('savedEvents')
          .doc('${userId}_$eventId')
          .delete();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: const Text('Saved Events',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(_error!)
              : _saved.isEmpty
                  ? _buildEmpty(context)
                  : _buildList(context, isDark, userId),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88, height: 88,
            decoration: const BoxDecoration(color: AppColors.purpleLight, shape: BoxShape.circle),
            child: const Icon(Icons.bookmark_border_rounded, color: AppColors.purple, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Nothing saved yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Tap the bookmark icon on any event to save it here for later.',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: AppColors.purple, foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.explore_rounded),
              label: const Text('Browse Events',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildList(BuildContext context, bool isDark, String userId) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: _saved.length,
      itemBuilder: (context, i) {
        final item = _saved[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _SavedCard(
            item: item, isDark: isDark,
            onUnsave: () => _unsave(userId, item.eventId),
            onTap: () => _openEventDetail(context, item.eventId),
          ),
        );
      },
    );
  }

  Future<void> _openEventDetail(BuildContext context, String eventId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events').doc(eventId).get();
      if (!doc.exists || !context.mounted) return;
      final event = EventModel.fromFirestore(doc).toEntity();
      Navigator.of(context).pushNamed(AppRoutes.eventDetail, arguments: event);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not load event'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _SavedItem {
  final String eventId, title, imageUrl, location, category,
      hostName, hostAvatar, hostId, dateStr;
  final DateTime savedAt;
  const _SavedItem({required this.eventId, required this.title,
      required this.imageUrl, required this.location, required this.category,
      required this.hostName, required this.hostAvatar, required this.hostId,
      required this.dateStr, required this.savedAt});
}

class _SavedCard extends StatelessWidget {
  final _SavedItem item;
  final bool isDark;
  final VoidCallback onTap, onUnsave;
  const _SavedCard({required this.item, required this.isDark,
      required this.onTap, required this.onUnsave});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    DateTime? date;
    try { date = DateTime.parse(item.dateStr); } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: surface,
            borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
            child: SizedBox(
              width: 100, height: 110,
              child: item.imageUrl.isNotEmpty
                  ? Image.network(item.imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: border,
                          child: const Icon(Icons.image_outlined, color: Colors.grey)))
                  : Container(color: border,
                      child: const Icon(Icons.image_outlined, color: Colors.grey)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.purpleLight,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(item.category,
                        style: const TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w600, color: AppColors.purple)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onUnsave,
                    child: const Icon(Icons.bookmark_rounded,
                        color: Color(0xFFFBBF24), size: 20),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(item.title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: textPrimary),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  Icon(Icons.location_on_outlined, size: 12, color: textSecondary),
                  const SizedBox(width: 3),
                  Expanded(child: Text(item.location,
                      style: TextStyle(fontSize: 12, color: textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: textSecondary),
                    const SizedBox(width: 3),
                    Text('${date.day}/${date.month}/${date.year}',
                        style: TextStyle(fontSize: 12, color: textSecondary)),
                  ]),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
