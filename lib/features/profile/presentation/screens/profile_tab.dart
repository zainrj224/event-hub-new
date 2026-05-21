import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/cache/cache_service.dart';
import '../../../../core/routes/app_routes.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  int _eventsCreated = 0;
  int _eventsSaved = 0;
  StreamSubscription? _eventsSub;
  StreamSubscription? _savedSub;
  // Cached profile overrides — shown instantly before Firebase resolves
  String? _cachedDisplayName;
  String? _cachedPhotoURL;

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _loadStats();
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    _savedSub?.cancel();
    super.dispose();
  }

  void _loadCachedProfile() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final cached = CacheService.instance.getProfile(userId);
    if (cached != null && mounted) {
      setState(() {
        _cachedDisplayName = cached['displayName'] as String?;
        _cachedPhotoURL = cached['photoURL'] as String?;
      });
    }
    // Also cache current user immediately for next launch
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      CacheService.instance.setProfile(userId, {
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'uid': userId,
      });
    }
  }

  void _loadStats() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _eventsSub = FirebaseFirestore.instance
        .collection('events')
        .where('hostId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _eventsCreated = snap.docs.length);
    });

    _savedSub = FirebaseFirestore.instance
        .collection('savedEvents')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _eventsSaved = snap.docs.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final name = _cachedDisplayName ?? user?.displayName ?? 'User';
    final email = user?.email ?? '';
    final initial =
        name.isNotEmpty ? name[0].toUpperCase() : (email.isNotEmpty ? email[0].toUpperCase() : 'U');
    final photoURL = _cachedPhotoURL ?? user?.photoURL;
    final hasPhoto = photoURL != null && photoURL.isNotEmpty;

    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB);
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary = isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280);

    // Member since date
    final creationTime = user?.metadata.creationTime;
    final memberSince = creationTime != null
        ? '${_monthName(creationTime.month)} ${creationTime.year}'
        : 'Unknown';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 32),

              // ── Avatar + name + email ──────────────────────────────
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.purpleLight,
                backgroundImage: hasPhoto ? NetworkImage(photoURL) : null,
                onBackgroundImageError: hasPhoto ? (_, __) {} : null,
                child: !hasPhoto
                    ? Text(initial,
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.w700,
                            color: AppColors.purple))
                    : null,
              ),
              const SizedBox(height: 14),
              Text(name,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textPrimary)),
              const SizedBox(height: 4),
              Text(email, style: TextStyle(fontSize: 14, color: textSecondary)),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.calendar_month_outlined, size: 14, color: textSecondary),
                const SizedBox(width: 4),
                Text('Member since $memberSince',
                    style: TextStyle(fontSize: 12, color: textSecondary)),
              ]),

              const SizedBox(height: 24),

              // ── Stats ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: surface, borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Row(children: [
                  _StatCell(value: _eventsCreated.toString(), label: 'Created', isDark: isDark),
                  _VertDivider(isDark: isDark),
                  _StatCell(value: _eventsSaved.toString(), label: 'Saved', isDark: isDark),
                  _VertDivider(isDark: isDark),
                  _StatCell(value: memberSince.split(' ').last, label: 'Since', isDark: isDark),
                ]),
              ),

              const SizedBox(height: 28),

              // ── Menu tiles ────────────────────────────────────────
              _ProfileTile(
                icon: Icons.event_note_rounded,
                label: 'My Events',
                isDark: isDark,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.myEvents),
              ),
              _ProfileTile(
                icon: Icons.bookmark_border_rounded,
                label: 'Saved Events',
                isDark: isDark,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.savedEvents),
              ),
              _ProfileTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                isDark: isDark,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
              ),

              const SizedBox(height: 16),

              // ── Sign out ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  label: const Text('Sign Out',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final bool isDark;
  const _StatCell({required this.value, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B7280))),
      ]),
    );
  }
}

class _VertDivider extends StatelessWidget {
  final bool isDark;
  const _VertDivider({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
      height: 36, width: 1,
      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB));
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  const _ProfileTile(
      {required this.icon, required this.label, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: ListTile(
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppColors.purpleLight,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.purple, size: 20),
        ),
        title: Text(label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary)),
        trailing: Icon(Icons.chevron_right_rounded,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9CA3AF)),
        onTap: onTap,
      ),
    );
  }
}
