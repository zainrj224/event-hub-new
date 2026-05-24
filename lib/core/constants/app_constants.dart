class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Event Discovery';
  static const String appVersion = '1.0.0';

  // Categories
  static const List<String> eventCategories = [
    'Technology',
    'Music',
    'Outdoors',
    'Food & Drink',
    'Health & Wellness',
    'Social',
    'Art & Culture',
    'Sports',
  ];

  // Date & Time
  static const int maxDaysInFuture = 365;
  
  // Pagination
  static const int eventsPerPage = 10;
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String eventsCollection = 'events';
  static const String attendeesCollection = 'attendees';
}
