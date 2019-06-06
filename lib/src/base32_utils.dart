class Base32Utils {
  //  number of bits per base 32 character
  static const BITS_PER_BASE32_CHAR = 5;
  //String representing the Base32 character map
  static const _BASE32_CHARS = '0123456789bcdefghjkmnpqrstuvwxyz';

  ///
  /// This method convert a given value to his corresponding Base32 character
  ///
  static String valueToBase32Char(int value) {
    if (value < 0 || value >= _BASE32_CHARS.length)
      throw FormatException("Not a valid base32 value: $value");
    return _BASE32_CHARS[value];
  }

  ///
  /// This method convert a given Base32 character to his corresponding value
  ///
  static int base32CharToValue(String base32Char) {
    final value = _BASE32_CHARS.indexOf(base32Char);
    if (value == -1)
      throw FormatException("Not a valid base32 char: $base32Char");
    return value;
  }

  ///
  /// This method check if a given geo hash is valid
  ///
  static bool isValidBase32String(String string) {
    final RegExp regex = new RegExp('^[$_BASE32_CHARS]*\$');
    return regex.hasMatch(string);
  }
}
