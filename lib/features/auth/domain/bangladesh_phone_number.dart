class BangladeshPhoneNumber {
  const BangladeshPhoneNumber._();

  static final RegExp _mobileSubscriberPattern = RegExp(r'^1[3-9]\d{8}$');
  static final RegExp _separators = RegExp(r'[\s\-()]');

  /// Converts a Bangladeshi mobile number to the E.164 format used by Firebase.
  ///
  /// Accepted prefixes include +880, 880, 00880, 0, or no prefix. Spaces,
  /// hyphens, parentheses, and Bengali numerals are also accepted.
  static String normalize(String input) {
    var number = _convertBengaliDigits(
      input.trim(),
    ).replaceAll(_separators, '');

    if (number.startsWith('+')) {
      number = number.substring(1);
    }
    if (number.startsWith('00')) {
      number = number.substring(2);
    }
    if (number.startsWith('880')) {
      number = number.substring(3);
    }
    if (number.startsWith('0')) {
      number = number.substring(1);
    }

    if (!_mobileSubscriberPattern.hasMatch(number)) {
      throw const FormatException(
        'Enter a valid Bangladesh mobile number, for example '
        '+8801712345678, 01712345678, or 1712345678.',
      );
    }

    return '+880$number';
  }

  static String _convertBengaliDigits(String value) {
    const bengaliDigits = '০১২৩৪৫৬৭৮৯';
    final buffer = StringBuffer();

    for (final character in value.split('')) {
      final digit = bengaliDigits.indexOf(character);
      buffer.write(digit == -1 ? character : digit);
    }

    return buffer.toString();
  }
}
