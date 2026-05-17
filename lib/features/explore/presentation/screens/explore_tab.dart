import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../features/events/data/models/event_model.dart';
import '../../../../features/events/domain/entities/event_entity.dart';
import '../../../../features/events/presentation/widgets/event_card.dart';

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Event>> _searchStream() {
    return FirebaseFirestore.instance
        .collection('events')
        .orderBy('title')
        .snapshots()
        .map((snap) {
      final events = snap.docs
          .map((doc) => EventModel.fromFirestore(doc).toEntity())
          .toList();
      if (_query.isEmpty) return events;
      final q = _query.toLowerCase();
      return events
          .where((e) =>
              e.title.toLowerCase().contains(q) ||
              e.description.toLowerCase().contains(q) ||
              e.category.toLowerCase().contains(q) ||
              e.location.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Explore',
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Find events that match your vibe',
                      style:
                          TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search events, places, categories…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF9CA3AF)),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            Expanded(
              child: StreamBuilder<List<Event>>(
                stream: _searchStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final events = snapshot.data ?? [];
                  if (events.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 56, color: AppColors.purple.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'No events found'
                                : 'No results for "$_query"',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => EventCard(
                      event: events[i],
                      onTap: () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.eventDetail,
                          arguments: events[i],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
