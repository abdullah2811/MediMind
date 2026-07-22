import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationReportEntry {
  const MedicationReportEntry({
    required this.id,
    required this.medicationId,
    required this.medicineName,
    required this.doseLabel,
    required this.scheduledAt,
    this.medicineStatus,
    this.medicineTakenAt,
    this.mealStatus,
    this.mealTakenAt,
    this.takenWithMeal = false,
  });

  final String id;
  final String medicationId;
  final String medicineName;
  final String doseLabel;
  final DateTime scheduledAt;
  final String? medicineStatus;
  final DateTime? medicineTakenAt;
  final String? mealStatus;
  final DateTime? mealTakenAt;
  final bool takenWithMeal;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'medicationId': medicationId,
    'medicineName': medicineName,
    'doseLabel': doseLabel,
    'scheduledAt': scheduledAt.toIso8601String(),
    'medicineStatus': medicineStatus,
    'medicineTakenAt': medicineTakenAt?.toIso8601String(),
    'mealStatus': mealStatus,
    'mealTakenAt': mealTakenAt?.toIso8601String(),
    'takenWithMeal': takenWithMeal,
  };

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'id': id,
    'medicationId': medicationId,
    'medicineName': medicineName,
    'doseLabel': doseLabel,
    'scheduledAt': Timestamp.fromDate(scheduledAt),
    'medicineStatus': medicineStatus,
    'medicineTakenAt': medicineTakenAt == null
        ? null
        : Timestamp.fromDate(medicineTakenAt!),
    'mealStatus': mealStatus,
    'mealTakenAt': mealTakenAt == null
        ? null
        : Timestamp.fromDate(mealTakenAt!),
    'takenWithMeal': takenWithMeal,
  };

  factory MedicationReportEntry.fromJson(Map<String, dynamic> json) {
    return MedicationReportEntry(
      id: json['id'] as String? ?? '',
      medicationId: json['medicationId'] as String? ?? '',
      medicineName: json['medicineName'] as String? ?? '',
      doseLabel: json['doseLabel'] as String? ?? '',
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      medicineStatus: json['medicineStatus'] as String?,
      medicineTakenAt: _dateTimeOrNull(json['medicineTakenAt']),
      mealStatus: json['mealStatus'] as String?,
      mealTakenAt: _dateTimeOrNull(json['mealTakenAt']),
      takenWithMeal: json['takenWithMeal'] as bool? ?? false,
    );
  }
}

class MedicationReport {
  const MedicationReport({
    required this.id,
    required this.rangeDays,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.entries,
  });

  final String id;
  final int rangeDays;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final List<MedicationReportEntry> entries;

  int get medicinesTaken =>
      entries.where((entry) => entry.medicineStatus == 'taken').length;
  int get medicinesNotTaken =>
      entries.where((entry) => entry.medicineStatus == 'notTaken').length;
  int get mealsTaken =>
      entries.where((entry) => entry.mealStatus == 'taken').length;
  int get mealsNotTaken =>
      entries.where((entry) => entry.mealStatus == 'notTaken').length;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'rangeDays': rangeDays,
    'periodStart': periodStart.toIso8601String(),
    'periodEnd': periodEnd.toIso8601String(),
    'generatedAt': generatedAt.toIso8601String(),
    'entries': entries.map((entry) => entry.toJson()).toList(growable: false),
  };

  Map<String, dynamic> toFirestore({required String uid}) => <String, dynamic>{
    'reportId': id,
    'uid': uid,
    'rangeDays': rangeDays,
    'periodStart': Timestamp.fromDate(periodStart),
    'periodEnd': Timestamp.fromDate(periodEnd),
    'generatedAt': Timestamp.fromDate(generatedAt),
    'summary': <String, int>{
      'medicinesTaken': medicinesTaken,
      'medicinesNotTaken': medicinesNotTaken,
      'mealsTaken': mealsTaken,
      'mealsNotTaken': mealsNotTaken,
    },
    'entries': entries
        .map((entry) => entry.toFirestore())
        .toList(growable: false),
  };

  factory MedicationReport.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'] as List<dynamic>? ?? const <dynamic>[];
    return MedicationReport(
      id: json['id'] as String? ?? '',
      rangeDays: (json['rangeDays'] as num?)?.toInt() ?? 7,
      periodStart: DateTime.parse(json['periodStart'] as String),
      periodEnd: DateTime.parse(json['periodEnd'] as String),
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      entries: rawEntries
          .map(
            (entry) => MedicationReportEntry.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

DateTime? _dateTimeOrNull(dynamic value) {
  if (value is DateTime) {
    return value;
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}
