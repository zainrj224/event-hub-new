import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/cache/cache_service.dart';
import '../../../../core/cache/cached_firestore.dart';
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
  String _selectedCategory = 'All';
  StreamSubscription<List<Event>>? _subscription;

  // Local cache — holds the latest events list
  List<Event> _events = [];
  bool _initialLoading = true;   // only true on very first load
  String? _error;

  final List<String> _categories = [
    'All', 'Music', 'Tech', 'Sports', 'Art', 'Food', 'Business', 'Education'
  ];

  @override
  void initState() {
    super.initState();
    _subscribe('All');
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribe(String category) {
    _subscription?.cancel();

    // Cache-first: show cached data instantly, then refresh from Firestore
    CachedFirestore.instance.fetchEvents(
      category: category,
      onCached: (cached) {
        if (!mounted) return;
        if (cached != null && cached.isNotEmpty) {
          final events = cached.map((m) {
            try { return EventModel.fromMap(m).toEntity(); } catch (_) { return null; }
          }).whereType<Event>().toList();
          if (mounted) setState(() { _events = events; _initialLoading = false; });
        }
      },
      onFresh: (fresh) {
        if (!mounted) return;
        final events = fresh.map((m) {
          try { return EventModel.fromMap(m).toEntity(); } catch (_) { return null; }
        }).whereType<Event>().toList();
        if (mounted) setState(() { _events = events; _initialLoading = false; _error = null; });
      },
      onError: (e) {
        // If we already have cached data showing, don't flash an error
        if (!mounted) return;
        if (_events.isEmpty) {
          setState(() { _initialLoading = false; _error = e.toString(); });
        }
      },
    );

    // Also keep a live Firestore listener for real-time updates
    Query<Map<String, dynamic>> query;
    if (category == 'All') {
      query = FirebaseFirestore.instance
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(50);
    } else {
      query = FirebaseFirestore.instance
          .collection('events')
          .where('category', isEqualTo: category)
          .limit(50);
    }

    _subscription = query.snapshots().map((snap) {
      final list = snap.docs.map((doc) {
        try { return EventModel.fromFirestore(doc).toEntity(); }
        catch (_) { return null; }
      }).whereType<Event>().toList();
      if (category != 'All') list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).listen(
      (events) {
        if (mounted) setState(() { _events = events; _initialLoading = false; _error = null; });
        // Update cache on every fresh snapshot
        CacheService.instance.setEvents(category,
            events.map((e) => _eventToMap(e)).toList());
      },
      onError: (e) {
        if (mounted && _events.isEmpty) {
          setState(() { _initialLoading = false; _error = e.toString(); });
        }
      },
    );
  }

  Map<String, dynamic> _eventToMap(Event e) => {
    'id': e.id, 'title': e.title, 'description': e.description,
    'date': e.date.toIso8601String(), 'time': e.time,
    'location': e.location, 'category': e.category,
    'image': e.image, 'hostId': e.hostId, 'hostName': e.hostName,
    'hostAvatar': e.hostAvatar, 'interested': e.interested,
    'attendees': e.attendees, 'isOnline': e.isOnline,
    'isPublic': e.isPublic, 'tags': e.tags,
    'createdAt': e.createdAt.toIso8601String(),
  };

  void _onCategoryTap(String cat) {
    if (cat == _selectedCategory) return;
    setState(() {
      _selectedCategory = cat;
      // Don't reset _events here — keep showing old list while new one loads
    });
    _subscribe(cat);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Hey, $name 👋',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          const Text('Discover events near you',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF6B7280))),
                        ],
                      ),
                    ),
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppColors.purpleLight,
                      backgroundImage: user?.photoURL != null
                          ? NetworkImage(user!.photoURL!)
                          : null,
                      child: user?.photoURL == null
                          ? Text(
                              (user?.displayName?.isNotEmpty == true
                                      ? user!.displayName![0]
                                      : user?.email?[0] ?? 'U')
                                  .toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.purple,
                                  fontWeight: FontWeight.w700))
                          : null,
                    ),
                  ],
                ),
              ),
            ),

            // ── Search bar ───────────────────────────────────────────────
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
                    child: const Row(
                      children: [
                        SizedBox(width: 14),
                        Icon(Icons.search_rounded,
                            color: Color(0xFF9CA3AF), size: 20),
                        SizedBox(width: 8),
                        Text('Search events...',
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Category chips ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final selected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => _onCategoryTap(cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          gradient:
                              selected ? AppColors.primaryGradient : null,
                          color: selected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // ── Section title ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Text(
                  _selectedCategory == 'All'
                      ? 'Upcoming Events'
                      : '$_selectedCategory Events',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),

            // ── Events list ──────────────────────────────────────────────
            if (_initialLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.error_outline,
                  title: 'Something went wrong',
                  subtitle: _error!,
                ),
              )
            else if (_events.isEmpty)
              SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'No events yet',
                  subtitle: _selectedCategory == 'All'
                      ? 'Be the first to create one!'
                      : 'No $_selectedCategory events found.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: EventCard(
                        event: _events[index],
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.eventDetail,
                            arguments: _events[index],
                          );
                        },
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

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.purpleLight,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.purple, size: 36),
          ),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
