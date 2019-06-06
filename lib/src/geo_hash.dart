import 'dart:math';

import 'package:geo_firestore/src/base32_utils.dart';

class GeoHash {
  // The default precision of a geohash
  static const DEFAULT_PRECISION = 10;

  // The maximal precision of a geohash
  static const MAX_PRECISION = 22;

  // The maximal number of bits precision for a geohash
  static const MAX_PRECISION_BITS =
      MAX_PRECISION * Base32Utils.BITS_PER_BASE32_CHAR;

  /// Encode a latitude and longitude pair into a geohash string.
  static String encode(final double latitude, final double longitude,
      {final int precision: DEFAULT_PRECISION}) {
    if (precision > MAX_PRECISION) {
      throw new ArgumentError(
          'latitude and longitude are not precise enough to encode $precision characters');
    }
    final latitudeBase2 = (latitude + 90) * (pow(2.0, 52) / 180);
    final longitudeBase2 = (longitude + 180) * (pow(2.0, 52) / 360);
    final longitudeBits = (precision ~/ 2) * 5 + (precision % 2) * 3;
    final latitudeBits = precision * 5 - longitudeBits;
    var longitudeCode = longitudeBase2.floor() >> (52 - longitudeBits);
    var latitudeCode = latitudeBase2.floor() >> (52 - latitudeBits);

    final stringBuffer = [];
    for (var localPrecision = precision; localPrecision > 0; localPrecision--) {
      int bigEndCode, littleEndCode;
      if (localPrecision % 2 == 0) {
        // Even slot. Latitude is more significant.
        bigEndCode = latitudeCode;
        littleEndCode = longitudeCode;
        latitudeCode >>= 3;
        longitudeCode >>= 2;
      } else {
        bigEndCode = longitudeCode;
        littleEndCode = latitudeCode;
        latitudeCode >>= 2;
        longitudeCode >>= 3;
      }
      final code = ((bigEndCode & 4) << 2) |
          ((bigEndCode & 2) << 1) |
          (bigEndCode & 1) |
          ((littleEndCode & 2) << 2) |
          ((littleEndCode & 1) << 1);
      stringBuffer.add(Base32Utils.valueToBase32Char(code));
    }
    final buffer = new StringBuffer()..writeAll(stringBuffer.reversed);
    return buffer.toString();
  }

  /// Get the rectangle that covers the entire area of a geohash string.
  static Rectangle<double> getExtents(String geohash) {
    final precision = geohash.length;
    if (precision > MAX_PRECISION) {
      throw new ArgumentError(
          'latitude and longitude are not precise enough to encode $precision characters');
    }
    var latitudeInt = 0;
    var longitudeInt = 0;
    var longitudeFirst = true;
    for (var character
        in geohash.codeUnits.map((r) => new String.fromCharCode(r))) {
      int thisSequence;
      try {
        thisSequence = Base32Utils.base32CharToValue(character);
      } catch (error) {
        throw new ArgumentError('$geohash was not a geohash string');
      }
      final bigBits = ((thisSequence & 16) >> 2) |
          ((thisSequence & 4) >> 1) |
          (thisSequence & 1);
      final smallBits = ((thisSequence & 8) >> 2) | ((thisSequence & 2) >> 1);
      if (longitudeFirst) {
        longitudeInt = (longitudeInt << 3) | bigBits;
        latitudeInt = (latitudeInt << 2) | smallBits;
      } else {
        longitudeInt = (longitudeInt << 2) | smallBits;
        latitudeInt = (latitudeInt << 3) | bigBits;
      }
      longitudeFirst = !longitudeFirst;
    }
    final longitudeBits = (precision ~/ 2) * 5 + (precision % 2) * 3;
    final latitudeBits = precision * 5 - longitudeBits;

    longitudeInt = longitudeInt << (52 - longitudeBits);
    latitudeInt = latitudeInt << (52 - latitudeBits);
    final longitudeDiff = 1 << (52 - longitudeBits);
    final latitudeDiff = 1 << (52 - latitudeBits);
    final latitude = latitudeInt.toDouble() * (180 / pow(2.0, 52)) - 90;
    final longitude = longitudeInt.toDouble() * (360 / pow(2.0, 52)) - 180;
    final height = latitudeDiff.toDouble() * (180 / pow(2.0, 52));
    final width = longitudeDiff.toDouble() * (360 / pow(2.0, 52));
    return Rectangle<double>(latitude + height, longitude, height, width);
    //I know this is backward, but it's because lat/lng are backwards.
  }

  /// Get a single number that is the center of a specific geohash rectangle.
  static Point<double> decode(String geohash) {
    final extents = getExtents(geohash);
    final x = extents.left + extents.width / 2;
    final y = extents.bottom + extents.height / 2;
    return new Point<double>(x, y);
  }
}
