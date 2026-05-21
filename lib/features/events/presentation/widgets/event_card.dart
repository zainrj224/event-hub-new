import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/event_entity.dart';
import '../../../../core/utils/date_formatter.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(isDark),
            _buildContent(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(bool isDark) {
    final placeholder = Container(
      color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
      child: const Center(child: Icon(Icons.image, color: Colors.grey, size: 36)),
    );
    Widget imageWidget;
    if (event.image.startsWith('data:')) {
      try {
        final bytes = base64Decode(event.image.split(',').last);
        imageWidget = Image.memory(bytes, fit: BoxFit.cover,
            width: double.infinity, height: 192,
            errorBuilder: (_, __, ___) => placeholder);
      } catch (_) { imageWidget = placeholder; }
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: event.image, fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
        errorWidget: (_, __, ___) => placeholder,
      );
    }
    return Stack(
      children: [
        SizedBox(height: 192, width: double.infinity, child: imageWidget),
        _buildImageBadges(isDark),
      ],
    );
  }

  Widget _buildImageBadges(bool isDark) {
    return Positioned(
      top: 12,
      left: 12,
      child: Row(
        children: [
          _buildBadge(
            event.category,
            isDark ? const Color(0xFF1F2937) : Colors.white,
            isDark ? Colors.white : const Color(0xFF111827),
          ),
          if (event.isOnline) ...[
            const SizedBox(width: 8),
            _buildBadge(
              '🌐 Online',
              const Color(0xFF3B82F6),
              Colors.white,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            event.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textPrimary,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Date & Time
          _buildInfoRow(
            Icons.calendar_today_outlined,
            DateFormatter.formatDateTime(event.date, event.time),
            textSecondary,
          ),
          const SizedBox(height: 4),

          // Location
          _buildInfoRow(
            Icons.location_on_outlined,
            event.location,
            textSecondary,
            expandable: true,
          ),
          const SizedBox(height: 12),

          // Tags
          if (event.tags.isNotEmpty) _buildTags(isDark),

          const SizedBox(height: 12),

          // Host & Stats
          _buildFooter(isDark, textSecondary),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    Color color, {
    bool expandable = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        if (expandable)
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          Text(
            text,
            style: TextStyle(fontSize: 13, color: color),
          ),
      ],
    );
  }

  Widget _buildTags(bool isDark) {
    final tagBg = isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    final tagText = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: event.tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tagBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              event.tags[index],
              style: TextStyle(fontSize: 12, color: tagText),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHostAvatar(bool isDark) {
    final bg = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final initial = event.hostName.isNotEmpty ? event.hostName[0].toUpperCase() : '?';
    final fallback = CircleAvatar(
      radius: 14,
      backgroundColor: bg,
      child: Text(initial,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: Color(0xFF9333EA))),
    );
    if (event.hostAvatar.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: event.hostAvatar,
      imageBuilder: (_, imageProvider) => CircleAvatar(
        radius: 14,
        backgroundImage: imageProvider,
        backgroundColor: bg,
      ),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }

  Widget _buildFooter(bool isDark, Color textSecondary) {
    return Row(
      children: [
        _buildHostAvatar(isDark),
        const SizedBox(width: 8),
        
        // Host Name
        Expanded(
          child: Text(
            event.hostName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Stats
        _buildStat(Icons.people_outline, event.attendees.toString(), textSecondary),
        const SizedBox(width: 12),
        _buildStat(Icons.favorite_border, event.interested.toString(), textSecondary),
      ],
    );
  }

  Widget _buildStat(IconData icon, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          count,
          style: TextStyle(fontSize: 13, color: color),
        ),
      ],
    );
  }
}
