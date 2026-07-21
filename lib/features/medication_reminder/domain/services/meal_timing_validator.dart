import '../models/medication.dart';

const mealTimingConflictWindowMinutes = 60;

class MealTimingConflict {
  const MealTimingConflict({
    required this.requestedMedicineTime,
    required this.requestedMealTime,
    required this.existingMealTime,
    required this.suggestedMedicineTime,
  });

  final String requestedMedicineTime;
  final String requestedMealTime;
  final String existingMealTime;
  final String suggestedMedicineTime;
}

MealTimingConflict? findMealTimingConflict({
  required List<String> newDoseTimes,
  required int newMealOffset,
  required List<Medication> existingMedications,
  String? excludedMedicationId,
  int conflictWindowMinutes = mealTimingConflictWindowMinutes,
}) {
  final existingMealMinutes = <int>[];
  for (final medication in existingMedications) {
    if (medication.id == excludedMedicationId ||
        !medication.mealScheduleEnabled) {
      continue;
    }
    for (final dose in medication.effectiveDoses) {
      existingMealMinutes.add(
        _normalizeMinutes(
          _clockMinutes(dose.timeOfDay) - medication.mealOffset,
        ),
      );
    }
  }

  for (final doseTime in newDoseTimes) {
    final requestedMeal = _normalizeMinutes(
      _clockMinutes(doseTime) - newMealOffset,
    );
    for (final existingMeal in existingMealMinutes) {
      final distance = _circularDistance(requestedMeal, existingMeal);
      if (distance == 0 || distance > conflictWindowMinutes) {
        continue;
      }
      return MealTimingConflict(
        requestedMedicineTime: _formatMinutes(_clockMinutes(doseTime)),
        requestedMealTime: _formatMinutes(requestedMeal),
        existingMealTime: _formatMinutes(existingMeal),
        suggestedMedicineTime: _formatMinutes(
          _normalizeMinutes(existingMeal + newMealOffset),
        ),
      );
    }
    existingMealMinutes.add(requestedMeal);
  }
  return null;
}

int _clockMinutes(String value) {
  final parts = value.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return hour.clamp(0, 23) * 60 + minute.clamp(0, 59);
}

int _normalizeMinutes(int value) => value % Duration.minutesPerDay;

int _circularDistance(int left, int right) {
  final direct = (left - right).abs();
  return direct < Duration.minutesPerDay - direct
      ? direct
      : Duration.minutesPerDay - direct;
}

String _formatMinutes(int value) {
  return '${(value ~/ 60).toString().padLeft(2, '0')}:'
      '${(value % 60).toString().padLeft(2, '0')}';
}
