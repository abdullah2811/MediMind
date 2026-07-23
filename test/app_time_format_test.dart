import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/core/formatting/app_time_format.dart';

void main() {
  test('always formats times with Latin digits and English AM/PM', () {
    expect(
      formatEnglish12Hour(const TimeOfDay(hour: 0, minute: 5)),
      '12:05 AM',
    );
    expect(
      formatEnglish12Hour(const TimeOfDay(hour: 12, minute: 30)),
      '12:30 PM',
    );
    expect(
      formatEnglish12Hour(const TimeOfDay(hour: 23, minute: 9)),
      '11:09 PM',
    );
  });
}
