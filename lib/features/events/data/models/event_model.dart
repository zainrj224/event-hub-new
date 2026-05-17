import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/event_entity.dart';

/// Data model for Event - used for Firebase serialization
class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String image;
  final String location;
  final double? locationLat;
  final double? locationLng;
  final String date; // Store as ISO string in Firebase
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
  final Timestamp createdAt;
  final Timestamp? updatedAt;

  const EventModel({
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

  // Convert from Firestore document
  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      image: data['image'] ?? '',
      location: data['location'] ?? '',
      locationLat: data['locationLat']?.toDouble(),
      locationLng: data['locationLng']?.toDouble(),
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      isOnline: data['isOnline'] ?? false,
      attendees: data['attendees'] ?? 0,
      interested: data['interested'] ?? 0,
      maxAttendees: data['maxAttendees'],
      isPublic: data['isPublic'] ?? true,
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      hostAvatar: data['hostAvatar'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'],
    );
  }


  /// Deserialise from cache (dates are ISO strings, not Timestamps)
  factory EventModel.fromMap(Map<String, dynamic> data) {
    Timestamp parseTs(dynamic v) {
      if (v is Timestamp) return v;
      if (v is String) return Timestamp.fromDate(DateTime.parse(v));
      return Timestamp.now();
    }

    return EventModel(
      id: data['id'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      image: data['image'] ?? '',
      location: data['location'] ?? '',
      locationLat: (data['locationLat'] as num?)?.toDouble(),
      locationLng: (data['locationLng'] as num?)?.toDouble(),
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      isOnline: data['isOnline'] ?? false,
      attendees: data['attendees'] ?? 0,
      interested: data['interested'] ?? 0,
      maxAttendees: data['maxAttendees'],
      isPublic: data['isPublic'] ?? true,
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      hostAvatar: data['hostAvatar'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
      createdAt: parseTs(data['createdAt']),
      updatedAt: data['updatedAt'] != null ? parseTs(data['updatedAt']) : null,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'image': image,
      'location': location,
      if (locationLat != null) 'locationLat': locationLat,
      if (locationLng != null) 'locationLng': locationLng,
      'date': date,
      'time': time,
      'isOnline': isOnline,
      'attendees': attendees,
      'interested': interested,
      if (maxAttendees != null) 'maxAttendees': maxAttendees,
      'isPublic': isPublic,
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatar': hostAvatar,
      'tags': tags,
      'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  // Convert from domain entity
  factory EventModel.fromEntity(Event event) {
    return EventModel(
      id: event.id,
      title: event.title,
      description: event.description,
      category: event.category,
      image: event.image,
      location: event.location,
      locationLat: event.locationLat,
      locationLng: event.locationLng,
      date: event.date.toIso8601String(),
      time: event.time,
      isOnline: event.isOnline,
      attendees: event.attendees,
      interested: event.interested,
      maxAttendees: event.maxAttendees,
      isPublic: event.isPublic,
      hostId: event.hostId,
      hostName: event.hostName,
      hostAvatar: event.hostAvatar,
      tags: event.tags,
      createdAt: Timestamp.fromDate(event.createdAt),
      updatedAt: event.updatedAt != null ? Timestamp.fromDate(event.updatedAt!) : null,
    );
  }

  // Convert to domain entity
  Event toEntity() {
    return Event(
      id: id,
      title: title,
      description: description,
      category: category,
      image: image,
      location: location,
      locationLat: locationLat,
      locationLng: locationLng,
      date: DateTime.parse(date),
      time: time,
      isOnline: isOnline,
      attendees: attendees,
      interested: interested,
      maxAttendees: maxAttendees,
      isPublic: isPublic,
      hostId: hostId,
      hostName: hostName,
      hostAvatar: hostAvatar,
      tags: tags,
      createdAt: createdAt.toDate(),
      updatedAt: updatedAt?.toDate(),
    );
  }
}
