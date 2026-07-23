import '../models/medication.dart';

Medication? findMatchingMedication({
  required String medicineName,
  required String? formula,
  required List<MedicationDose> doses,
  required List<Medication> existingMedications,
  String? excludedMedicationId,
}) {
  final normalizedName = _normalize(medicineName);
  final normalizedFormula = _normalize(formula ?? '');
  final dosage = _dosageSignature(doses);

  for (final medication in existingMedications) {
    if (medication.id == excludedMedicationId) {
      continue;
    }
    var matches = 0;
    if (normalizedName == _normalize(medication.medicineName)) {
      matches++;
    }
    if (dosage.isNotEmpty &&
        dosage == _dosageSignature(medication.effectiveDoses)) {
      matches++;
    }
    final existingFormula = _normalize(medication.formula ?? '');
    if (normalizedFormula.isNotEmpty &&
        existingFormula.isNotEmpty &&
        normalizedFormula == existingFormula) {
      matches++;
    }
    if (matches >= 2) {
      return medication;
    }
  }
  return null;
}

String _dosageSignature(List<MedicationDose> doses) {
  final values =
      doses
          .map(
            (dose) =>
                '${_normalize(dose.dosageValue)}|'
                '${_normalize(dose.dosageUnit)}',
          )
          .where((value) => !value.startsWith('|'))
          .toList(growable: false)
        ..sort();
  return values.join(';');
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
