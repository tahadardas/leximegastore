import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../errors/app_failure.dart';

enum LocationAddressErrorCode {
  locationServicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  gpsTimeout,
  gpsUnavailable,
}

class LocationAddressException extends AppFailure {
  final LocationAddressErrorCode errorCode;

  LocationAddressException({required this.errorCode, required String message})
    : super(message);
}

class LocationAddress {
  final String address;
  final String city;

  const LocationAddress({required this.address, required this.city});
}

class LocationAddressDetails {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime capturedAt;
  final String fullAddress;
  final String country;
  final String city;
  final String area;
  final String street;
  final String building;
  final String postalCode;

  const LocationAddressDetails({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.capturedAt,
    required this.fullAddress,
    required this.country,
    required this.city,
    required this.area,
    required this.street,
    required this.building,
    required this.postalCode,
  });
}

class LocationAddressService {
  static const _defaultTimeout = Duration(seconds: 15);

  static Future<LocationAddress> getCurrentAddress() async {
    final details = await getCurrentLocationDetails();
    return LocationAddress(
      address: details.fullAddress,
      city: details.city.isNotEmpty ? details.city : 'الموقع الحالي',
    );
  }

  static Future<LocationAddressDetails> getCurrentLocationDetails({
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationAddressException(
          errorCode: LocationAddressErrorCode.locationServicesDisabled,
          message: 'يرجى تفعيل خدمات الموقع على جهازك.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.deniedForever) {
        throw LocationAddressException(
          errorCode: LocationAddressErrorCode.permissionDeniedForever,
          message: 'تم رفض صلاحية الموقع بشكل دائم. افتح الإعدادات.',
        );
      }
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw LocationAddressException(
          errorCode: LocationAddressErrorCode.permissionDenied,
          message: 'تم رفض صلاحية الموقع.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw LocationAddressException(
          errorCode: LocationAddressErrorCode.permissionDeniedForever,
          message: 'تم رفض صلاحية الموقع بشكل دائم. افتح الإعدادات.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(timeout);

      return _reverseGeocode(position);
    } on LocationAddressException {
      rethrow;
    } on TimeoutException {
      throw LocationAddressException(
        errorCode: LocationAddressErrorCode.gpsTimeout,
        message: 'انتهت المهلة أثناء تحديد موقعك عبر GPS.',
      );
    } catch (_) {
      throw LocationAddressException(
        errorCode: LocationAddressErrorCode.gpsUnavailable,
        message: 'تعذر قراءة موقعك الحالي الآن.',
      );
    }
  }

  static Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  static Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  static Future<LocationAddressDetails> _reverseGeocode(
    Position position,
  ) async {
    Placemark? place;

    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        place = placemarks.first;
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[LocationAddressService] Reverse geocoding failed: $error');
      }
    }

    final city = _firstNonEmpty([
      place?.locality,
      place?.subAdministrativeArea,
      place?.administrativeArea,
    ]);
    final area = _firstNonEmpty([
      place?.subLocality,
      place?.subAdministrativeArea,
      place?.locality,
    ]);
    final street = _firstNonEmpty([
      place?.street,
      place?.thoroughfare,
      place?.name,
    ]);
    final building = _firstNonEmpty([place?.subThoroughfare, place?.name]);
    final country = _firstNonEmpty([place?.country]);
    final postalCode = _firstNonEmpty([place?.postalCode]);

    var fullAddress = _joinNonEmpty([street, area, city, country, postalCode]);
    if (fullAddress.isEmpty) {
      final lat = position.latitude.toStringAsFixed(6);
      final lng = position.longitude.toStringAsFixed(6);
      fullAddress = 'الموقع الحالي ($lat, $lng)';
    }

    return LocationAddressDetails(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy > 0 ? position.accuracy : null,
      capturedAt: DateTime.now().toUtc(),
      fullAddress: fullAddress,
      country: country,
      city: city,
      area: area,
      street: street,
      building: building,
      postalCode: postalCode,
    );
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = (value ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  static String _joinNonEmpty(List<String?> values) {
    final items = values
        .map((value) => (value ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return items.join(', ');
  }
}
