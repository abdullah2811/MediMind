import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/data/services/medication_notification_service.dart';
import 'package:medimind/features/medication_reminder/domain/models/medication.dart';

void main() {
  Medication medication({
    required String id,
    required String doseTime,
    required int mealOffset,
    String scheduleFrequency = 'daily',
    int customIntervalDays = 1,
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
      scheduleFrequency: scheduleFrequency,
      customIntervalDays: customIntervalDays,
      scheduleStartDate: DateTime(2026, 7, 22),
      isActive: true,
      updatedAt: DateTime(2026, 7, 22),
    );
  }

  test('overlapping meal reminders are merged into one clock event', () {
    final plan = buildMedicationReminderPlan(
      [
        medication(id: 'Before', doseTime: '08:40', mealOffset: -20),
        medication(id: 'After', doseTime: '09:20', mealOffset: 20),
      ],
      from: DateTime(2026, 7, 22, 8),
      horizonDays: 0,
    );

    expect(plan.map((item) => _clock(item.scheduledAt)), [
      '08:40',
      '09:00',
      '09:20',
    ]);
    final mealEvent = plan.singleWhere(
      (item) => _clock(item.scheduledAt) == '09:00',
    );
    expect(mealEvent.hasMedicine, isFalse);
    expect(
      mealEvent.meals.map((item) => item.id),
      containsAll(['Before', 'After']),
    );
  });

  test('medicine taken with a meal creates one combined reminder', () {
    final plan = buildMedicationReminderPlan(
      [medication(id: 'Together', doseTime: '12:00', mealOffset: 0)],
      from: DateTime(2026, 7, 22, 11),
      horizonDays: 0,
    );

    expect(plan, hasLength(1));
    expect(plan.single.hasMedicine, isTrue);
    expect(plan.single.hasMeal, isTrue);
  });

  test('weekly medicine is only planned on its recurrence day', () {
    final medicine = medication(
      id: 'Weekly',
      doseTime: '09:00',
      mealOffset: 0,
      scheduleFrequency: 'weekly',
    );

    final offDay = buildMedicationReminderPlan(
      [medicine],
      from: DateTime(2026, 7, 23),
      horizonDays: 5,
    );
    expect(offDay, isEmpty);

    final nextWeek = buildMedicationReminderPlan(
      [medicine],
      from: DateTime(2026, 7, 23),
      horizonDays: 6,
    );
    expect(nextWeek, hasLength(1));
    expect(nextWeek.single.scheduledAt, DateTime(2026, 7, 29, 9));
  });

  test('custom recurrence uses the selected number of days', () {
    final plan = buildMedicationReminderPlan(
      [
        medication(
          id: 'Custom',
          doseTime: '09:00',
          mealOffset: 0,
          scheduleFrequency: 'custom',
          customIntervalDays: 3,
        ),
      ],
      from: DateTime(2026, 7, 22, 8),
      horizonDays: 7,
    );

    expect(plan.map((item) => item.scheduledAt.day), [22, 25, 28]);
  });
}

String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
