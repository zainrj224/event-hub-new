import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/event_entity.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';

class EventDetailScreen extends StatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLiked = false;
  bool _isSaved = false;
  bool _likeLoading = true;
  late int _likeCount;

  Event get event => widget.event;

  bool get _isExpired => event.date.isBefore(DateTime.now());
  bool get _shouldAutoDelete =>
      _isExpired && DateTime.now().difference(event.date).inHours >= 24;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.event.interested;
    _checkUserInterest();
    _checkSaved();
    if (_shouldAutoDelete) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoDelete());
    }
  }

  Future<void> _autoDelete() async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .delete();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This event was automatically removed after 24 hours.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _checkUserInterest() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) { setState(() => _likeLoading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('interested')
          .doc('${event.id}_$userId')
          .get();
      if (mounted) setState(() { _isLiked = doc.exists; _likeLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _likeLoading = false);
    }
  }

  Future<void> _checkSaved() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('savedEvents')
          .doc('${userId}_${event.id}')
          .get();
      if (mounted) setState(() => _isSaved = doc.exists);
    } catch (_) {}
  }

  Future<void> _toggleInterested() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in to mark interest'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final newLiked = !_isLiked;
    setState(() { _isLiked = newLiked; _likeCount += newLiked ? 1 : -1; });
    try {
      final docRef = FirebaseFirestore.instance
          .collection('interested').doc('${event.id}_$userId');
      final eventRef = FirebaseFirestore.instance.collection('events').doc(event.id);
      if (newLiked) {
        await docRef.set({'eventId': event.id, 'userId': userId,
            'timestamp': FieldValue.serverTimestamp()});
        await eventRef.update({'interested': FieldValue.increment(1)});
      } else {
        await docRef.delete();
        await eventRef.update({'interested': FieldValue.increment(-1)});
      }
    } catch (_) {
      if (mounted) setState(() { _isLiked = !newLiked; _likeCount += newLiked ? -1 : 1; });
    }
  }

  Future<void> _toggleSave() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final newSaved = !_isSaved;
    setState(() => _isSaved = newSaved);
    final ref = FirebaseFirestore.instance
        .collection('savedEvents').doc('${userId}_${event.id}');
    try {
      if (newSaved) {
        await ref.set({
          'userId': userId, 'eventId': event.id,
          'savedAt': FieldValue.serverTimestamp(),
          'eventTitle': event.title, 'eventDate': event.date.toIso8601String(),
          'eventImage': event.image, 'eventLocation': event.location,
          'eventCategory': event.category, 'hostName': event.hostName,
          'hostAvatar': event.hostAvatar, 'hostId': event.hostId,
        });
      } else {
        await ref.delete();
      }
    } catch (_) {
      if (mounted) setState(() => _isSaved = !newSaved);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Event', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to permanently delete this event? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('events').doc(event.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Event deleted'), behavior: SnackBarBehavior.floating));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to delete: $e'), behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCreator = currentUserId != null && currentUserId == event.hostId;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.45),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      child: IconButton(
                        icon: Icon(
                          _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          color: _isSaved ? const Color(0xFFFBBF24) : Colors.white,
                          size: 18,
                        ),
                        onPressed: _toggleSave,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      child: IconButton(
                        icon: const Icon(Icons.share_rounded, color: Colors.white, size: 18),
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share coming soon!'), behavior: SnackBarBehavior.floating)),
                      ),
                    ),
                  ),
                  if (isCreator) ...[
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8, right: 8),
                      child: CircleAvatar(
                        backgroundColor: Colors.red.withValues(alpha: 0.75),
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                          onPressed: _confirmDelete,
                        ),
                      ),
                    ),
                  ],
                ],
                flexibleSpace: FlexibleSpaceBar(background: _buildHeroImage(isDark)),
              ),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBadgesRow(isDark),
                    _buildTitle(isDark),
                    if (_isExpired) _buildExpiredBanner(),
                    _buildStatusBanner(isDark),
                    _buildDivider(isDark),
                    _buildDateTimeSection(isDark),
                    _buildDivider(isDark),
                    _buildLocationSection(isDark),
                    _buildDivider(isDark),
                    _buildDescriptionSection(isDark),
                    if (event.tags.isNotEmpty) ...[ _buildDivider(isDark), _buildTagsSection(isDark) ],
                    _buildDivider(isDark),
                    _buildHostSection(isDark),
                    _buildDivider(isDark),
                    _buildAttendeesSection(isDark),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomBar(isDark, isCreator),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner() {
    final hoursAgo = DateTime.now().difference(event.date).inHours;
    final hoursLeft = (24 - hoursAgo).clamp(0, 24);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFFB45309)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This event has ended',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                  const SizedBox(height: 2),
                  Text(
                    hoursLeft > 0
                        ? 'It will be automatically deleted in ${hoursLeft}h'
                        : 'It will be deleted very soon',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroImage(bool isDark) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: event.image, fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
          errorWidget: (_, __, ___) => Container(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 56),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0, height: 80,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent,
                  (isDark ? AppColors.darkBackground : Colors.white).withValues(alpha: 0.85)],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadgesRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Wrap(
        spacing: 8, runSpacing: 6,
        children: [
          _badge(event.category, AppColors.purpleLight, AppColors.purple),
          if (event.isOnline)
            _badge('🌐 Online', const Color(0xFFDBEAFE), const Color(0xFF1D4ED8)),
          if (event.isHappeningSoon && !_isExpired)
            _badge('⚡ Happening Soon', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
          if (_isExpired)
            _badge('⏰ Ended', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
          if (!event.isPublic)
            _badge('🔒 Private', const Color(0xFFF3F4F6), const Color(0xFF374151)),
        ],
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _buildTitle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Text(event.title, style: TextStyle(
        fontSize: 26, fontWeight: FontWeight.w800,
        color: isDark ? AppColors.darkText : AppColors.lightText, height: 1.25)),
    );
  }

  Widget _buildStatusBanner(bool isDark) {
    if (!event.isFull && event.maxAttendees == null) return const SizedBox.shrink();
    final isFull = event.isFull;
    final bg = isFull ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5);
    final fg = isFull ? const Color(0xFFB91C1C) : const Color(0xFF065F46);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(isFull ? Icons.block_rounded : Icons.check_circle_outline, size: 16, color: fg),
          const SizedBox(width: 8),
          Text(isFull ? 'This event is full'
              : 'Available: ${event.maxAttendees! - event.attendees} of ${event.maxAttendees} spots',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg)),
        ]),
      ),
    );
  }

  Widget _buildDateTimeSection(bool isDark) {
    return _sectionPadding(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconCircle(Icons.calendar_today_rounded, isDark),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Date & Time', isDark),
          const SizedBox(height: 4),
          Text(DateFormatter.formatDateLong(event.date), style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText)),
          const SizedBox(height: 2),
          Text('${DateFormatter.formatTime(event.time)}  ·  ${DateFormatter.getRelativeDate(event.date)}',
              style: TextStyle(fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isExpired ? const Color(0xFFFEE2E2) : AppColors.purpleLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(DateFormatter.getTimeUntilEvent(event.date, event.time),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                    color: _isExpired ? const Color(0xFFB91C1C) : AppColors.purple)),
          ),
        ])),
      ]),
    );
  }

  Widget _buildLocationSection(bool isDark) {
    return _sectionPadding(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _iconCircle(event.isOnline ? Icons.video_call_rounded : Icons.location_on_rounded, isDark),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel(event.isOnline ? 'Online Event' : 'Location', isDark),
          const SizedBox(height: 4),
          Text(event.location, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText)),
        ])),
      ]),
    );
  }

  Widget _buildDescriptionSection(bool isDark) {
    return _sectionPadding(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('About this event', isDark),
        const SizedBox(height: 8),
        Text(event.description.isNotEmpty ? event.description : 'No description provided.',
            style: TextStyle(fontSize: 15, height: 1.6,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
      ]),
    );
  }

  Widget _buildTagsSection(bool isDark) {
    return _sectionPadding(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Tags', isDark),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
          children: event.tags.map((tag) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(tag, style: TextStyle(fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          )).toList(),
        ),
      ]),
    );
  }

  Widget _avatarFallback(Color bg, String initial) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: bg,
      child: Text(initial,
          style: const TextStyle(fontWeight: FontWeight.w700,
              fontSize: 18, color: AppColors.purple)),
    );
  }

  Widget _buildHostSection(bool isDark) {
    final avatarBg = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final hasAvatar = event.hostAvatar.isNotEmpty;
    final hostInitial = event.hostName.isNotEmpty ? event.hostName[0].toUpperCase() : '?';

    // Use CachedNetworkImage with explicit errorWidget so the initial
    // letter always shows when the image URL is empty or fails to load.
    final Widget avatarWidget = hasAvatar
        ? CachedNetworkImage(
            imageUrl: event.hostAvatar,
            imageBuilder: (_, imageProvider) => CircleAvatar(
              radius: 24,
              backgroundImage: imageProvider,
              backgroundColor: avatarBg,
            ),
            placeholder: (_, __) => _avatarFallback(avatarBg, hostInitial),
            errorWidget: (_, __, ___) => _avatarFallback(avatarBg, hostInitial),
          )
        : _avatarFallback(avatarBg, hostInitial);

    return _sectionPadding(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Hosted by', isDark),
        const SizedBox(height: 12),
        Row(children: [
          avatarWidget,
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.hostName, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText)),
            const SizedBox(height: 2),
            Text('Event Organizer', style: TextStyle(fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ])),
        ]),
      ]),
    );
  }

  Widget _buildAttendeesSection(bool isDark) {
    return _sectionPadding(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Event Stats', isDark),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _statCard(icon: Icons.people_rounded, label: 'Attending',
              value: event.attendees.toString(), isDark: isDark)),
          const SizedBox(width: 12),
          Expanded(child: _statCard(icon: Icons.favorite_rounded, label: 'Interested',
              value: _likeCount.toString(), isDark: isDark)),
          if (event.maxAttendees != null) ...[
            const SizedBox(width: 12),
            Expanded(child: _statCard(icon: Icons.confirmation_num_rounded, label: 'Capacity',
                value: event.maxAttendees.toString(), isDark: isDark)),
          ],
        ]),
      ]),
    );
  }

  Widget _statCard({required IconData icon, required String label,
      required String value, required bool isDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [
        Icon(icon, size: 20, color: AppColors.purple),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
      ]),
    );
  }

  Widget _buildBottomBar(bool isDark, bool isCreator) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(top: BorderSide(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB))),
      ),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: _likeLoading ? null : _toggleInterested,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _isLiked ? AppColors.pinkLight
                    : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: _isLiked ? AppColors.pink : Colors.transparent),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_likeLoading)
                  SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      _isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      key: ValueKey(_isLiked),
                      color: _isLiked ? AppColors.pink
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      size: 22,
                    ),
                  ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Text(_likeCount.toString(), key: ValueKey(_likeCount),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: _isLiked ? AppColors.pink
                          : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
                ),
              ]),
            ),
          ),
        ),
        if (isCreator) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _confirmDelete,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFB91C1C)),
                SizedBox(width: 6),
                Text('Delete', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C))),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _sectionPadding({required Widget child}) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 18), child: child);

  Widget _buildDivider(bool isDark) => Divider(height: 1, thickness: 1,
      color: isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6), indent: 20, endIndent: 20);

  Widget _sectionLabel(String text, bool isDark) => Text(text, style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8,
      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary));

  Widget _iconCircle(IconData icon, bool isDark) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: AppColors.purpleLight, borderRadius: BorderRadius.circular(12)),
    child: Icon(icon, color: AppColors.purple, size: 20),
  );
}
