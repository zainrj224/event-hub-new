import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/routes/app_routes.dart';
import '../../data/models/event_model.dart';
import '../../domain/entities/event_entity.dart';
import '../widgets/event_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  List<Event> _allEvents = [];
  List<Event> _results = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Auto-focus search input when screen opens
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .limit(200)
          .get();
      final events = snap.docs.map((doc) {
        try { return EventModel.fromFirestore(doc).toEntity(); }
        catch (_) { return null; }
      }).whereType<Event>().toList();

      if (mounted) {
        setState(() {
          _allEvents = events;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String q) {
    setState(() {
      _query = q.trim().toLowerCase();
      if (_query.isEmpty) {
        _results = [];
        return;
      }
      _results = _allEvents.where((e) =>
        e.title.toLowerCase().contains(_query) ||
        e.description.toLowerCase().contains(_query) ||
        e.category.toLowerCase().contains(_query) ||
        e.location.toLowerCase().contains(_query) ||
        e.hostName.toLowerCase().contains(_query) ||
        e.tags.any((t) => t.toLowerCase().contains(_query))
      ).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final border = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? AppColors.darkText : AppColors.lightText;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onSearch,
          style: TextStyle(color: textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search events, places, hosts...',
            hintStyle: TextStyle(color: textSecondary, fontSize: 15),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, color: textSecondary),
              onPressed: () {
                _ctrl.clear();
                _onSearch('');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? _buildSuggestions(isDark, textSecondary)
              : _results.isEmpty
                  ? _buildNoResults(isDark, textSecondary)
                  : _buildResults(isDark),
    );
  }

  Widget _buildSuggestions(bool isDark, Color textSecondary) {
    // Show popular categories as quick suggestions
    const categories = ['Music', 'Tech', 'Sports', 'Art', 'Food', 'Business', 'Education'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('Browse by Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 10, runSpacing: 10,
            children: categories.map((cat) => GestureDetector(
              onTap: () {
                _ctrl.text = cat;
                _onSearch(cat);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.purpleLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(cat, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: AppColors.purple)),
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults(bool isDark, Color textSecondary) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(
              color: AppColors.purpleLight, shape: BoxShape.circle),
          child: const Icon(Icons.search_off_rounded,
              color: AppColors.purple, size: 36),
        ),
        const SizedBox(height: 16),
        Text('No results for "$_query"',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText)),
        const SizedBox(height: 6),
        Text('Try a different keyword or category',
            style: TextStyle(fontSize: 13, color: textSecondary)),
      ]),
    );
  }

  Widget _buildResults(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: _results.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: EventCard(
          event: _results[i],
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.eventDetail, arguments: _results[i]),
        ),
      ),
    );
  }
}
