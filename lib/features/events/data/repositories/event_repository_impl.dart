import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/event_entity.dart';
import '../../domain/repositories/event_repository.dart';
import '../models/event_model.dart';
import '../../../../core/cache/cache_service.dart';

class EventRepositoryImpl implements EventRepository {
  final FirebaseFirestore _firestore;
  final String _collection = 'events';

  EventRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<Event>> getEvents() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc).toEntity())
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch events: $e');
    }
  }

  @override
  Future<List<Event>> getEventsByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('category', isEqualTo: category)
          .orderBy('date')
          .get();

      return snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc).toEntity())
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch events by category: $e');
    }
  }

  @override
  Future<Event?> getEventById(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();

      if (!doc.exists) {
        return null;
      }

      return EventModel.fromFirestore(doc).toEntity();
    } catch (e) {
      throw Exception('Failed to fetch event: $e');
    }
  }

  @override
  Future<String> createEvent(Event event) async {
    try {
      // Invalidate event caches so home refreshes
      final docRef = await _firestore.collection(_collection).add(
        EventModel.fromEntity(event).toFirestore(),
      );

      await CacheService.instance.invalidateEvents();
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  @override
  Future<void> updateEvent(Event event) async {
    await CacheService.instance.invalidateEvents();
    try {
      await _firestore
          .collection(_collection)
          .doc(event.id)
          .update(EventModel.fromEntity(event).toFirestore());
    } catch (e) {
      throw Exception('Failed to update event: $e');
    }
  }

  @override
  Future<void> deleteEvent(String eventId) async {
    await CacheService.instance.invalidateEvents();
    try {
      await _firestore.collection(_collection).doc(eventId).delete();
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }

  @override
  Future<List<Event>> searchEvents(String query) async {
    try {
      final lowercaseQuery = query.toLowerCase();

      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('title')
          .get();

      // Filter in memory since Firestore doesn't support full-text search
      final events = snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc).toEntity())
          .where((event) =>
              event.title.toLowerCase().contains(lowercaseQuery) ||
              event.description.toLowerCase().contains(lowercaseQuery) ||
              event.category.toLowerCase().contains(lowercaseQuery))
          .toList();

      return events;
    } catch (e) {
      throw Exception('Failed to search events: $e');
    }
  }

  @override
  Future<List<Event>> getUserEvents(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('hostId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => EventModel.fromFirestore(doc).toEntity())
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user events: $e');
    }
  }

  @override
  Future<void> attendEvent(String eventId, String userId) async {
    try {
      final eventRef = _firestore.collection(_collection).doc(eventId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(eventRef);

        if (!snapshot.exists) {
          throw Exception('Event not found');
        }

        final currentAttendees = snapshot.data()?['attendees'] ?? 0;
        transaction.update(eventRef, {
          'attendees': currentAttendees + 1,
        });

        // Also create an attendee record
        final attendeeRef = _firestore
            .collection('attendees')
            .doc('${eventId}_$userId');
        transaction.set(attendeeRef, {
          'eventId': eventId,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to attend event: $e');
    }
  }

  @override
  Future<void> markInterested(String eventId, String userId) async {
    try {
      final eventRef = _firestore.collection(_collection).doc(eventId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(eventRef);

        if (!snapshot.exists) {
          throw Exception('Event not found');
        }

        final currentInterested = snapshot.data()?['interested'] ?? 0;
        transaction.update(eventRef, {
          'interested': currentInterested + 1,
        });

        // Create an interested record
        final interestedRef = _firestore
            .collection('interested')
            .doc('${eventId}_$userId');
        transaction.set(interestedRef, {
          'eventId': eventId,
          'userId': userId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Failed to mark interested: $e');
    }
  }
}
