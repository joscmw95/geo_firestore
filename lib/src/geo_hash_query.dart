import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geo_firestore/src/base32_utils.dart';
import 'package:geo_firestore/src/geo_constants.dart';
import 'package:geo_firestore/src/geo_firestore.dart';
import 'package:geo_firestore/src/geo_hash.dart';
import 'package:geo_firestore/src/geo_utils.dart';

class GeoHashQuery {
  final String startValue;
  final String endValue;

  GeoHashQuery({this.startValue, this.endValue});

  static double bitsLatitudeForResolution(double resolution) {
    return min(log(EARTH_MERIDIONAL_CIRCUMFERENCE / 2 / resolution) / log(2.0),
        GeoHash.MAX_PRECISION_BITS.toDouble());
  }

  static double bitsLongitudeForResolution(double resolution, double latitude) {
    final degrees = GeoUtils.distanceToLongitudeDegrees(resolution, latitude);
    return degrees.abs() > 0 ? max(1.0, log(360 / degrees) / log(2.0)) : 1.0;
  }

  static int bitsForBoundingBox(GeoPoint location, double size) {
    final latitudeDegreesDelta = GeoUtils.distanceToLatitudeDegrees(size);
    final latitudeNorth = min(90.0, location.latitude + latitudeDegreesDelta);
    final latitudeSouth = max(-90.0, location.latitude - latitudeDegreesDelta);
    final bitsLatitude = (bitsLatitudeForResolution(size).floor() * 2).toInt();
    final bitsLongitudeNorth =
        (bitsLongitudeForResolution(size, latitudeNorth).floor() * 2 - 1)
            .toInt();
    final bitsLongitudeSouth =
        (bitsLongitudeForResolution(size, latitudeSouth).floor() * 2 - 1)
            .toInt();
    return min(bitsLatitude, min(bitsLongitudeNorth, bitsLongitudeSouth));
  }

  static GeoHashQuery queryForGeoHash(String hash, int bits) {
    final precision =
        (bits.toDouble() / Base32Utils.BITS_PER_BASE32_CHAR).ceil().toInt();
    if (hash.length < precision) {
      return GeoHashQuery(startValue: hash, endValue: '$hash~');
    }
    hash = hash.substring(0, precision);
    final base = hash.substring(0, hash.length - 1);
    final lastValue = Base32Utils.base32CharToValue(hash[hash.length - 1]);
    final significantBits =
        bits - (base.length * Base32Utils.BITS_PER_BASE32_CHAR);
    final unusedBits = Base32Utils.BITS_PER_BASE32_CHAR - significantBits;
    // delete unused bits
    final startValue = (lastValue >> unusedBits) << unusedBits;
    final endValue = startValue + (1 << unusedBits);
    final startHash = base + Base32Utils.valueToBase32Char(startValue);
    final endHash = (endValue > 31)
        ? '$base~'
        : base + Base32Utils.valueToBase32Char(endValue);
    return GeoHashQuery(startValue: startHash, endValue: endHash);
  }

  static Set<GeoHashQuery> queriesAtLocation(GeoPoint location, double radius) {
    final queryBits = max(1, bitsForBoundingBox(location, radius));
    final geoHashPrecision =
        (queryBits.toDouble() / Base32Utils.BITS_PER_BASE32_CHAR)
            .ceil()
            .toInt();

    final latitude = location.latitude;
    final longitude = location.longitude;
    final latitudeDegrees = radius / METERS_PER_DEGREE_LATITUDE;
    final latitudeNorth = min(90.0, latitude + latitudeDegrees);
    final latitudeSouth = max(-90.0, latitude - latitudeDegrees);
    final longitudeDeltaNorth =
        GeoUtils.distanceToLongitudeDegrees(radius, latitudeNorth);
    final longitudeDeltaSouth =
        GeoUtils.distanceToLongitudeDegrees(radius, latitudeSouth);
    final longitudeDelta = max(longitudeDeltaNorth, longitudeDeltaSouth);

    final queries = Set<GeoHashQuery>();

    final geoHash =
        GeoHash.encode(latitude, longitude, precision: geoHashPrecision);
    final geoHashW = GeoHash.encode(
        latitude, GeoUtils.wrapLongitude(longitude - longitudeDelta),
        precision: geoHashPrecision);
    final geoHashE = GeoHash.encode(
        latitude, GeoUtils.wrapLongitude(longitude + longitudeDelta),
        precision: geoHashPrecision);
    final geoHashN =
        GeoHash.encode(latitudeNorth, longitude, precision: geoHashPrecision);
    final geoHashNW = GeoHash.encode(
        latitudeNorth, GeoUtils.wrapLongitude(longitude - longitudeDelta),
        precision: geoHashPrecision);
    final geoHashNE = GeoHash.encode(
        latitudeNorth, GeoUtils.wrapLongitude(longitude + longitudeDelta),
        precision: geoHashPrecision);
    final geoHashS =
        GeoHash.encode(latitudeSouth, longitude, precision: geoHashPrecision);
    final geoHashSW = GeoHash.encode(
        latitudeSouth, GeoUtils.wrapLongitude(longitude - longitudeDelta),
        precision: geoHashPrecision);
    final geoHashSE = GeoHash.encode(
        latitudeSouth, GeoUtils.wrapLongitude(longitude + longitudeDelta),
        precision: geoHashPrecision);

    queries.add(queryForGeoHash(geoHash, queryBits));
    queries.add(queryForGeoHash(geoHashE, queryBits));
    queries.add(queryForGeoHash(geoHashW, queryBits));
    queries.add(queryForGeoHash(geoHashN, queryBits));
    queries.add(queryForGeoHash(geoHashNE, queryBits));
    queries.add(queryForGeoHash(geoHashNW, queryBits));
    queries.add(queryForGeoHash(geoHashS, queryBits));
    queries.add(queryForGeoHash(geoHashSE, queryBits));
    queries.add(queryForGeoHash(geoHashSW, queryBits));

    // Join queries
    bool didJoin;
    do {
      GeoHashQuery query1;
      GeoHashQuery query2;
      for (GeoHashQuery query in queries) {
        for (GeoHashQuery other in queries) {
          if (query != other && query._canJoinWith(other)) {
            query1 = query;
            query2 = other;
            break;
          }
        }
      }
      didJoin = (query1 != null && query2 != null);
      if (didJoin) {
        queries.remove(query1);
        queries.remove(query2);
        queries.add(query1._joinWith(query2));
      }
    } while (didJoin);
    return queries;
  }

  bool _isPrefix(GeoHashQuery other) =>
      (other.endValue.compareTo(this.startValue)) >= 0 &&
      (other.startValue.compareTo(this.startValue) < 0) &&
      (other.endValue.compareTo(this.endValue) < 0);

  bool _isSuperQuery(GeoHashQuery other) {
    return other.startValue.compareTo(this.startValue) <= 0 &&
        other.endValue.compareTo(endValue) >= 0;
  }

  bool _canJoinWith(GeoHashQuery other) =>
      this._isPrefix(other) ||
      other._isPrefix(this) ||
      this._isSuperQuery(other) ||
      other._isSuperQuery(this);

  GeoHashQuery _joinWith(GeoHashQuery other) {
    if (other._isPrefix(this)) {
      return GeoHashQuery(
          startValue: this.startValue, endValue: other.endValue);
    }
    if (this._isPrefix(other)) {
      return GeoHashQuery(
          startValue: other.startValue, endValue: this.endValue);
    }
    if (this._isSuperQuery(other)) {
      return other;
    }
    if (other._isSuperQuery(this)) {
      return this;
    }
    throw FormatException("Can't join these two queries: $this, $other");
  }

  Query createFirestoreQuery(GeoFirestore geoFirestore) {
    return geoFirestore.collectionReference
        .orderBy('geoHash')
        .startAt([this.startValue]).endAt([this.endValue]);
  }

  bool containsGeoHash(String hash) {
    return this.startValue.compareTo(hash) <= 0 &&
        this.endValue.compareTo(hash) > 0;
  }

  bool operator ==(dynamic other) {
    if (other == null || !(other is GeoHashQuery)) return false;
    if (endValue != other.endValue || startValue != other.startValue)
      return false;
    return true;
  }

  int get hashCode => (31 * startValue.hashCode + endValue.hashCode);

  toString() => "GeoHashQuery(startValue='$startValue', endValue='$endValue')";
}
