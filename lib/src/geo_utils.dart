import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geo_firestore/src/geo_constants.dart';

class GeoUtils {
  ///
  /// Checks if these coordinates are valid geo coordinates.
  /// [latitude]  The latitude must be in the range [-90, 90]
  /// [longitude] The longitude must be in the range [-180, 180]
  /// returns [true] if these are valid geo coordinates
  ///
  static bool coordinatesValid(double latitude, double longitude) {
    return (latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180);
  }

  ///
  /// Checks if the coordinates  of a GeopPoint are valid geo coordinates.
  /// [latitude]  The latitude must be in the range [-90, 90]
  /// [longitude] The longitude must be in the range [-180, 180]
  /// returns [true] if these are valid geo coordinates
  ///
  static bool geoPointValid(GeoPoint point) {
    return (point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180);
  }

  ///
  /// Wraps the longitude to [-180,180].
  ///
  /// [longitude] The longitude to wrap.
  /// returns The resulting longitude.
  ///
  static double wrapLongitude(double longitude) {
    if (longitude <= 180 && longitude >= -180) {
      return longitude;
    }
    final adjusted = longitude + 180;
    if (adjusted > 0) {
      return (adjusted % 360) - 180;
    }
    // else
    return 180 - (-adjusted % 360);
  }

  static double degreesToRadians(double degrees) {
    return (degrees * pi) / 180;
  }

  ///
  /// Calculates the number of degrees a given distance is at a given latitude.
  /// [distance] The distance to convert.
  /// [latitude] The latitude at which to calculate.
  /// returns the number of degrees the distance corresponds to.
  static double distanceToLongitudeDegrees(double distance, double latitude) {
    final radians = degreesToRadians(latitude);
    final numerator = cos(radians) * EARTH_EQ_RADIUS * pi / 180;
    final denom = 1 / sqrt(1 - E2 * sin(radians) * sin(radians));
    final deltaDeg = numerator * denom;
    if (deltaDeg < EPSILON) {
      return distance > 0 ? 360.0 : 0.0;
    }
    // else
    return min(360.0, distance / deltaDeg);
  }

  ///
  /// Calculates the distance, in kilometers, between two locations, via the
  /// Haversine formula. Note that this is approximate due to the fact that
  /// the Earth's radius varies between 6356.752 km and 6378.137 km.
  /// [p1] The first location given
  /// [p2] The second location given
  /// return the distance, in kilometers, between the two locations.
  ///
  static double distance(GeoPoint p1, GeoPoint p2) {
    final dlat = degreesToRadians(p2.latitude - p1.latitude);
    final dlon = degreesToRadians(p2.longitude - p1.longitude);
    final lat1 = degreesToRadians(p1.latitude);
    final lat2 = degreesToRadians(p2.latitude);

    final r = 6378.137; // WGS84 major axis
    double c = 2 *
        asin(sqrt(pow(sin(dlat / 2), 2) +
            cos(lat1) * cos(lat2) * pow(sin(dlon / 2), 2)));
    return r * c;
  }

  static double distanceToLatitudeDegrees(double distance) =>
      distance / METERS_PER_DEGREE_LATITUDE;

  static double capRadius(double radius) {
    if (radius > MAX_SUPPORTED_RADIUS) {
      print(
          "The radius is bigger than $MAX_SUPPORTED_RADIUS and hence we'll use that value");
      return MAX_SUPPORTED_RADIUS.toDouble();
    }
    return radius;
  }
}
