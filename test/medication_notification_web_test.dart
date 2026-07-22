import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/medication_reminder/data/services/medication_notification_service.dart';

void main() {
  test('notification operations are safe no-ops on web', () async {
    if (!kIsWeb) {
      return;
    }

    final service = MedicationNotificationService();
    await service.initialize();
    await service.rescheduleAll(const []);
    await service.cancelMedicationById('web-test');
  });
}
