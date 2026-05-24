import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service for handling location and geocoding operations
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  LocationService._internal();

  /// Get coordinates from address string
  Future<LatLng> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      
      if (locations.isEmpty) {
        throw Exception('Unable to find coordinates for the provided address');
      }

      final location = locations.first;
      return LatLng(location.latitude, location.longitude);
    } catch (e) {
      throw Exception('Geocoding failed: $e');
    }
  }

  /// Get address from coordinates
  Future<String> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isEmpty) {
        throw Exception('Unable to find address for the provided coordinates');
      }

      final placemark = placemarks.first;
      return _formatAddress(placemark);
    } catch (e) {
      throw Exception('Reverse geocoding failed: $e');
    }
  }

  /// Get current user location
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied');
    }

    // Get current position
    return await Geolocator.getCurrentPosition(
      accuracy: LocationAccuracy.high,
    );
  }

  /// Calculate distance between two coordinates (in kilometers)
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
  }

  /// Format placemark into readable address
  String _formatAddress(Placemark placemark) {
    final parts = <String>[];

    if (placemark.street?.isNotEmpty ?? false) parts.add(placemark.street!);
    if (placemark.locality?.isNotEmpty ?? false) parts.add(placemark.locality!);
    if (placemark.administrativeArea?.isNotEmpty ?? false) {
      parts.add(placemark.administrativeArea!);
    }
    if (placemark.country?.isNotEmpty ?? false) parts.add(placemark.country!);

    return parts.join(', ');
  }

  /// Validate coordinates
  bool isValidCoordinate(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }
}
