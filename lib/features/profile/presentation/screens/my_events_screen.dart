import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../events/data/models/event_model.dart';
import '../../../events/domain/entities/event_entity.dart';
import '../../../events/presentation/widgets/event_card.dart';

class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription? _subscription;
  List<Event> _myEvents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  void _subscribe() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    // NO orderBy — avoids composite index requirement; we sort in memory
    _subscription = FirebaseFirestore.instance
        .collection('events')
        .where('hostId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              try { return EventModel.fromFirestore(doc).toEntity(); }
              catch (_) { return null; }
            }).whereType<Event>().toList())
        .listen(
      (events) {
        // Sort in memory by date ascending
        events.sort((a, b) => a.date.compareTo(b.date));
        if (mounted) setState(() { _myEvents = events; _loading = false; _error = null; });
      },
      onError: (e) {
        if (mounted) setState(() { _loading = false; _error = e.toString(); });
      },
    );
  }

  List<Event> get _upcoming => _myEvents.where((e) => !e.hasStarted).toList();
  List<Event> get _past => _myEvents.where((e) => e.hasStarted).toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: surface,
        title: const Text('My Events', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.purple,
          labelColor: AppColors.purple,
          unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Past')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(_error!)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _EventsList(
                      events: _upcoming,
                      emptyTitle: 'No upcoming events',
                      emptySubtitle: 'Events you create will show up here.',
                      emptyIcon: Icons.event_note_rounded,
                    ),
                    _EventsList(
                      events: _past,
                      emptyTitle: 'No past events',
                      emptySubtitle: 'Events you have hosted will appear here once they end.',
                      emptyIcon: Icons.history_rounded,
                    ),
                  ],
                ),
    );
  }

  Widget _buildError(String msg) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
        const SizedBox(height: 12),
        const Text('Something went wrong',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(msg, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _EventsList extends StatelessWidget {
  final List<Event> events;
  final String emptyTitle, emptySubtitle;
  final IconData emptyIcon;

  const _EventsList({required this.events, required this.emptyTitle,
      required this.emptySubtitle, required this.emptyIcon});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(color: AppColors.purpleLight, shape: BoxShape.circle),
              child: Icon(emptyIcon, color: AppColors.purple, size: 36),
            ),
            const SizedBox(height: 16),
            Text(emptyTitle,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(emptySubtitle,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: events.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: EventCard(
          event: events[i],
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.eventDetail, arguments: events[i]),
        ),
      ),
    );
  }
}
