// lib/services/location_service.dart
import 'package:flutter/foundation.dart'; // For kIsWeb and TargetPlatform
import 'package:flutter/material.dart'; // For debugPrint
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async'; // Import needed for Duration
import 'dart:io' show Platform; // Explicitly import Platform

class LocationService {
  Position? _lastPosition;
  String? _lastFormattedAddress;
  DateTime? _lastLocationTime;

  // Handles requesting and checking location permissions.
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled. Please enable them.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
          'Location permissions are permanently denied, we cannot request permissions.');
      return false;
    }

    return true;
  }

  // Gets the current location and returns a formatted address string.
  Future<String> getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      return "Location access denied. Enable in settings.";
    }

    // Return cached location if recent enough
    if (_lastPosition != null &&
        _lastFormattedAddress != null &&
        _lastLocationTime != null &&
        DateTime.now().difference(_lastLocationTime!).inMinutes < 1) {
      debugPrint("Using cached location: $_lastFormattedAddress");
      return _lastFormattedAddress!;
    }

    debugPrint("Fetching new location...");
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      _lastPosition = position;
      _lastLocationTime = DateTime.now();

      final address = await _getAddressFromLatLng(position);
      _lastFormattedAddress = address;
      debugPrint("Fetched and formatted address: $address");

      return address;
    } on TimeoutException {
      debugPrint('Error getting location: Timeout');
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _lastPosition = lastKnown;
        final address = await _getAddressFromLatLng(lastKnown);
        _lastFormattedAddress = address;
        return "$address (Possibly outdated)";
      }
      return "Could not get location: Timeout. No last known location.";
    } catch (e) {
      debugPrint('Error getting location: $e');
      return "Unable to determine location. Check connection/permissions.";
    }
  }

  // Converts latitude/longitude coordinates into a human-readable address.
  Future<String> _getAddressFromLatLng(Position position) async {
    String fallbackCoordinates =
        'Lat: ${position.latitude.toStringAsFixed(5)}, Long: ${position.longitude.toStringAsFixed(5)}';

    if (kIsWeb) {
      return fallbackCoordinates + " (Web - Geocoding not attempted)";
    }

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final List<String> addressParts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].whereType<String>().where((part) => part.isNotEmpty).toList();

        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        }
      }
      debugPrint("Geocoding successful but no address parts found.");
      return fallbackCoordinates;
    } catch (e) {
      debugPrint('Error getting address from coordinates: $e');
      return fallbackCoordinates;
    }
  }

  // Opens the current location in the default map application.
  Future<bool> openLocationInMap() async {
    Position? positionToOpen = _lastPosition;

    // If no cached position, try fetching a new one
    if (positionToOpen == null) {
      debugPrint("No cached position, fetching new one for map...");
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        debugPrint('Permission denied for opening map location.');
        return false;
      }
      try {
        positionToOpen = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 10),
        );
        _lastPosition = positionToOpen;
      } on TimeoutException {
        debugPrint('Timeout getting location for map.');
        positionToOpen = await Geolocator.getLastKnownPosition();
        // FIX: Removed the redundant null check here.
        // If lastKnownPosition is also null, positionToOpen remains null.
      } catch (e) {
        debugPrint('Could not get current position for map: $e');
        // Ensure positionToOpen is null if fetching failed completely
        positionToOpen = null;
      }
    }

    // If after all attempts, position is still null
    if (positionToOpen == null) {
      debugPrint('Final check: Unable to determine position to open in map.');
      return false;
    }

    final lat = positionToOpen.latitude;
    final lng = positionToOpen.longitude;
    final String query = '$lat,$lng';

    Uri? mapUri;

    if (!kIsWeb && Platform.isIOS) {
      mapUri = Uri.parse('https://maps.apple.com/?q=$query');
      debugPrint("Attempting to launch Apple Maps: $mapUri");
    } else {
      // Use the standard Google Maps URL format
      mapUri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      debugPrint("Attempting to launch Google Maps: $mapUri");
    }

    Uri geoUri = Uri.parse('geo:$lat,$lng?q=$query');

    try {
      bool launched = false;
      if (await canLaunchUrl(mapUri)) {
        launched = await launchUrl(mapUri);
      }

      if (!launched && await canLaunchUrl(geoUri)) {
        debugPrint("Primary map launch failed, trying generic geo: $geoUri");
        launched = await launchUrl(geoUri);
      }

      if (!launched) {
        debugPrint(
            'Could not launch any suitable maps app for coordinates $lat,$lng.');
      }
      return launched;
    } catch (e) {
      debugPrint("Error launching map URL: $e");
      return false;
    }
  }
}
