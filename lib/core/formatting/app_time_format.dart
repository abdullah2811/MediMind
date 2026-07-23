import 'package:flutter/material.dart';

String formatEnglish12Hour(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

String formatEnglish12HourDateTime(DateTime time) {
  return formatEnglish12Hour(TimeOfDay.fromDateTime(time));
}

Widget buildEnglish12HourTimePicker(BuildContext context, Widget? child) {
  return Localizations.override(
    context: context,
    locale: const Locale('en'),
    child: MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
      child: child!,
    ),
  );
}
