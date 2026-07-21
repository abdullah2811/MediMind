import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/data/services/medication_notification_service.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';

void main() {
  Medication medication({
    required String id,
    required String doseTime,
    required int mealOffset,
  }) {
    return Medication(
      id: id,
      medicineName: id,
      dose: '1 pill',
      doses: [
        MedicationDose(
          timeOfDay: doseTime,
          dosageValue: '1',
          dosageUnit: 'pill',
        ),
      ],
      durationDays: 0,
      timeOfDay: doseTime,
      mealOffset: mealOffset,
      mealScheduleEnabled: true,
      isActive: true,
      updatedAt: DateTime(2026, 7, 22),
    );
  }

  test('overlapping meal reminders are merged into one clock event', () {
    final plan = buildMedicationReminderPlan([
      medication(id: 'Before', doseTime: '08:40', mealOffset: -20),
      medication(id: 'After', doseTime: '09:20', mealOffset: 20),
    ]);

    expect(plan.map((item) => item.timeOfDay), ['08:40', '09:00', '09:20']);
    final mealEvent = plan.singleWhere((item) => item.timeOfDay == '09:00');
    expect(mealEvent.hasMedicine, isFalse);
    expect(
      mealEvent.meals.map((item) => item.id),
      containsAll(['Before', 'After']),
    );
  });

  test('medicine taken with a meal creates one combined reminder', () {
    final plan = buildMedicationReminderPlan([
      medication(id: 'Together', doseTime: '12:00', mealOffset: 0),
    ]);

    expect(plan, hasLength(1));
    expect(plan.single.hasMedicine, isTrue);
    expect(plan.single.hasMeal, isTrue);
  });
}
