import 'package:equatable/equatable.dart';

/// Domain entity for Event
/// This is the core business object used throughout the app
class Event extends Equatable {
  final String id;
  final String title;
  final String description;
  final String category;
  final String image;
  final String location;
  final double? locationLat;
  final double? locationLng;
  final DateTime date;
  final String time;
  final bool isOnline;
  final int attendees;
  final int interested;
  final int? maxAttendees;
  final bool isPublic;
  final String hostId;
  final String hostName;
  final String hostAvatar;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.image,
    required this.location,
    this.locationLat,
    this.locationLng,
    required this.date,
    required this.time,
    this.isOnline = false,
    this.attendees = 0,
    this.interested = 0,
    this.maxAttendees,
    this.isPublic = true,
    required this.hostId,
    required this.hostName,
    required this.hostAvatar,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
  });

  // Copy with method for creating modified copies
  Event copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? image,
    String? location,
    double? locationLat,
    double? locationLng,
    DateTime? date,
    String? time,
    bool? isOnline,
    int? attendees,
    int? interested,
    int? maxAttendees,
    bool? isPublic,
    String? hostId,
    String? hostName,
    String? hostAvatar,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      image: image ?? this.image,
      location: location ?? this.location,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      date: date ?? this.date,
      time: time ?? this.time,
      isOnline: isOnline ?? this.isOnline,
      attendees: attendees ?? this.attendees,
      interested: interested ?? this.interested,
      maxAttendees: maxAttendees ?? this.maxAttendees,
      isPublic: isPublic ?? this.isPublic,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatar: hostAvatar ?? this.hostAvatar,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Formatted date string
  String get formattedDate {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Check if event has started
  bool get hasStarted {
    final now = DateTime.now();
    return date.isBefore(now) || date.isAtSameMomentAs(now);
  }

  // Check if event is full
  bool get isFull {
    return maxAttendees != null && attendees >= maxAttendees!;
  }

  // Check if event is happening soon (within 24 hours)
  bool get isHappeningSoon {
    final now = DateTime.now();
    final difference = date.difference(now);
    return difference.inHours <= 24 && difference.inHours >= 0;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        image,
        location,
        locationLat,
        locationLng,
        date,
        time,
        isOnline,
        attendees,
        interested,
        maxAttendees,
        isPublic,
        hostId,
        hostName,
        hostAvatar,
        tags,
        createdAt,
        updatedAt,
      ];
}
