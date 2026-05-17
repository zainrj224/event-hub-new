import '../entities/event_entity.dart';

/// Abstract repository interface for Event operations
/// This defines the contract that data layer must implement
abstract class EventRepository {
  /// Get all events
  Future<List<Event>> getEvents();

  /// Get events by category
  Future<List<Event>> getEventsByCategory(String category);

  /// Get event by ID
  Future<Event?> getEventById(String id);

  /// Create a new event
  Future<String> createEvent(Event event);

  /// Update an existing event
  Future<void> updateEvent(Event event);

  /// Delete an event
  Future<void> deleteEvent(String eventId);

  /// Search events by query
  Future<List<Event>> searchEvents(String query);

  /// Get events for a specific user
  Future<List<Event>> getUserEvents(String userId);

  /// Mark user as attending
  Future<void> attendEvent(String eventId, String userId);

  /// Mark user as interested
  Future<void> markInterested(String eventId, String userId);
}
