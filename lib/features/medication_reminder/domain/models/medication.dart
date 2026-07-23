import 'package:cloud_firestore/cloud_firestore.dart';

String calculateMealTime(String medicineTime, int mealOffsetMinutes) {
  final parts = medicineTime.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final medicineMinutes = hour * 60 + minute;
  final mealMinutes = (medicineMinutes - mealOffsetMinutes) % (24 * 60);
  return '${(mealMinutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(mealMinutes % 60).toString().padLeft(2, '0')}';
}

class MedicationDose {
  const MedicationDose({
    required this.timeOfDay,
    required this.dosageValue,
    required this.dosageUnit,
  });

  final String timeOfDay;
  final String dosageValue;
  final String dosageUnit;

  String get summary => '$timeOfDay — $dosageValue $dosageUnit';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'timeOfDay': timeOfDay,
    'dosageValue': dosageValue,
    'dosageUnit': dosageUnit,
  };

  factory MedicationDose.fromJson(Map<String, dynamic> json) {
    return MedicationDose(
      timeOfDay: json['timeOfDay'] as String? ?? '',
      dosageValue: json['dosageValue'] as String? ?? '',
      dosageUnit: json['dosageUnit'] as String? ?? '',
    );
  }
}

class MedicationCheckIn {
  const MedicationCheckIn({
    required this.dateKey,
    required this.doseTime,
    this.medicineStatus,
    this.mealStatus,
    this.medicineTakenAt,
    this.mealTakenAt,
    this.takenWithMeal = false,
  });

  final String dateKey;
  final String doseTime;
  final String? medicineStatus;
  final String? mealStatus;
  final DateTime? medicineTakenAt;
  final DateTime? mealTakenAt;
  final bool takenWithMeal;

  String get key => '$dateKey|$doseTime';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'dateKey': dateKey,
    'doseTime': doseTime,
    'medicineStatus': medicineStatus,
    'mealStatus': mealStatus,
    'medicineTakenAt': medicineTakenAt?.toIso8601String(),
    'mealTakenAt': mealTakenAt?.toIso8601String(),
    'takenWithMeal': takenWithMeal,
  };

  factory MedicationCheckIn.fromJson(Map<String, dynamic> json) {
    return MedicationCheckIn(
      dateKey: json['dateKey'] as String? ?? '',
      doseTime: json['doseTime'] as String? ?? '',
      medicineStatus: json['medicineStatus'] as String?,
      mealStatus: json['mealStatus'] as String?,
      medicineTakenAt: _dateTimeOrNull(json['medicineTakenAt']),
      mealTakenAt: _dateTimeOrNull(json['mealTakenAt']),
      takenWithMeal: json['takenWithMeal'] as bool? ?? false,
    );
  }
}

String medicationDateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class Medication {
  const Medication({
    required this.id,
    required this.medicineName,
    required this.dose,
    required this.durationDays,
    required this.timeOfDay,
    this.doseTimes = const <String>[],
    this.doses = const <MedicationDose>[],
    required this.mealOffset,
    this.mealScheduleEnabled = false,
    this.mealTimes = const <String>[],
    this.checkIns = const <MedicationCheckIn>[],
    this.scheduleFrequency = 'daily',
    this.customIntervalDays = 1,
    DateTime? scheduleStartDate,
    this.medicineType = 'tablet',
    this.powerValue,
    this.powerUnit = 'mg',
    this.languageCode = 'bn',
    this.formula,
    this.companyName,
    this.imagePath,
    this.imageBytesBase64,
    this.notes,
    this.backupImageUrl,
    required this.isActive,
    required this.updatedAt,
  }) : scheduleStartDate = scheduleStartDate ?? updatedAt;

  final String id;
  final String medicineName;
  final String medicineType;
  final String? powerValue;
  final String powerUnit;
  final String languageCode;
  final String? formula;
  final String? companyName;
  final String? imagePath;
  final String? imageBytesBase64;
  final String? backupImageUrl;
  final String dose;
  final int durationDays;
  final String timeOfDay;
  final List<String> doseTimes;
  final List<MedicationDose> doses;
  final int mealOffset;
  final bool mealScheduleEnabled;
  final List<String> mealTimes;
  final List<MedicationCheckIn> checkIns;
  final String scheduleFrequency;
  final int customIntervalDays;
  final DateTime scheduleStartDate;
  final String? notes;
  final bool isActive;
  final DateTime updatedAt;

  List<MedicationDose> get effectiveDoses {
    if (doses.isNotEmpty) {
      return doses;
    }
    final times = doseTimes.isNotEmpty
        ? doseTimes
        : <String>[if (timeOfDay.isNotEmpty) timeOfDay];
    return times
        .map(
          (time) => MedicationDose(
            timeOfDay: time,
            dosageValue: dose,
            dosageUnit: '',
          ),
        )
        .toList(growable: false);
  }

  String get powerLabel {
    final value = powerValue?.trim() ?? '';
    return value.isEmpty ? '' : '$value $powerUnit';
  }

  MedicationCheckIn? checkInFor(DateTime date, String doseTime) {
    final key = '${medicationDateKey(date)}|$doseTime';
    for (final checkIn in checkIns) {
      if (checkIn.key == key) {
        return checkIn;
      }
    }
    return null;
  }

  int get repeatIntervalDays {
    return switch (scheduleFrequency) {
      'weekly' => 7,
      'every15Days' => 15,
      'custom' => customIntervalDays.clamp(1, 365),
      _ => 1,
    };
  }

  bool occursOnDate(DateTime date) {
    final localStart = scheduleStartDate.toLocal();
    final start = DateTime(localStart.year, localStart.month, localStart.day);
    final candidate = DateTime(date.year, date.month, date.day);
    if (candidate.isBefore(start)) {
      return false;
    }
    if (scheduleFrequency == 'monthly') {
      final lastDay = DateTime(candidate.year, candidate.month + 1, 0).day;
      return candidate.day == localStart.day.clamp(1, lastDay);
    }
    return candidate.difference(start).inDays % repeatIntervalDays == 0;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'medicineName': medicineName,
    'medicineType': medicineType,
    'powerValue': powerValue,
    'powerUnit': powerUnit,
    'languageCode': languageCode,
    'formula': formula,
    'companyName': companyName,
    'imagePath': imagePath,
    'imageBytesBase64': imageBytesBase64,
    'backupImageUrl': backupImageUrl,
    'dose': dose,
    'durationDays': durationDays,
    'timeOfDay': timeOfDay,
    'doseTimes': doseTimes,
    'doses': doses.map((item) => item.toJson()).toList(growable: false),
    'mealOffset': mealOffset,
    'mealScheduleEnabled': mealScheduleEnabled,
    'mealTimes': mealTimes,
    'checkIns': checkIns.map((item) => item.toJson()).toList(growable: false),
    'scheduleFrequency': scheduleFrequency,
    'customIntervalDays': scheduleFrequency == 'custom'
        ? customIntervalDays
        : null,
    'scheduleStartDate': scheduleStartDate.toIso8601String(),
    'notes': notes,
    'isActive': isActive,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: json['id'] as String,
    medicineName: json['medicineName'] as String,
    medicineType: json['medicineType'] as String? ?? 'tablet',
    powerValue: json['powerValue'] as String?,
    powerUnit: json['powerUnit'] as String? ?? 'mg',
    languageCode: json['languageCode'] as String? ?? 'bn',
    formula: json['formula'] as String?,
    companyName: json['companyName'] as String?,
    imagePath: json['imagePath'] as String?,
    imageBytesBase64: json['imageBytesBase64'] as String?,
    backupImageUrl: json['backupImageUrl'] as String?,
    dose: json['dose'] as String? ?? '',
    durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
    timeOfDay: json['timeOfDay'] as String? ?? '',
    doseTimes: _stringList(json['doseTimes']),
    doses: _doseList(json['doses']),
    mealOffset: (json['mealOffset'] as num?)?.toInt() ?? 0,
    mealScheduleEnabled: json['mealScheduleEnabled'] as bool? ?? false,
    mealTimes: _stringList(json['mealTimes']),
    checkIns: _checkInList(json['checkIns']),
    scheduleFrequency: json['scheduleFrequency'] as String? ?? 'daily',
    customIntervalDays: (json['customIntervalDays'] as num?)?.toInt() ?? 1,
    scheduleStartDate: _dateTimeOrNull(json['scheduleStartDate']),
    notes: json['notes'] as String?,
    isActive: true,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toFirestore({
    required String uid,
    String? imageUrlOverride,
  }) => <String, dynamic>{
    'reminderId': id,
    'uid': uid,
    'medicineName': medicineName,
    'medicineType': medicineType,
    'powerValue': powerValue,
    'powerUnit': powerUnit,
    'languageCode': languageCode,
    'formula': formula,
    'companyName': companyName,
    'dose': dose,
    'durationDays': durationDays,
    'timeOfDay': timeOfDay,
    'doseTimes': doseTimes,
    'doses': doses.map((item) => item.toJson()).toList(growable: false),
    'mealOffset': mealOffset,
    'mealScheduleEnabled': mealScheduleEnabled,
    'mealTimes': mealTimes,
    'checkIns': checkIns.map((item) => item.toJson()).toList(growable: false),
    'scheduleFrequency': scheduleFrequency,
    'customIntervalDays': scheduleFrequency == 'custom'
        ? customIntervalDays
        : FieldValue.delete(),
    'scheduleStartDate': Timestamp.fromDate(scheduleStartDate),
    'imagePath': _cloudImageValue(imageUrlOverride),
    'notes': notes,
    'isActive': true,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Medication.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return Medication(
      id: data['reminderId'] as String? ?? snapshot.id,
      medicineName: data['medicineName'] as String? ?? '',
      medicineType: data['medicineType'] as String? ?? 'tablet',
      powerValue: data['powerValue'] as String?,
      powerUnit: data['powerUnit'] as String? ?? 'mg',
      languageCode: data['languageCode'] as String? ?? 'bn',
      formula: data['formula'] as String?,
      companyName: data['companyName'] as String?,
      imagePath: data['imagePath'] as String?,
      backupImageUrl: data['imagePath'] as String?,
      imageBytesBase64: null,
      dose: data['dose'] as String? ?? '',
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 0,
      timeOfDay: data['timeOfDay'] as String? ?? '',
      doseTimes: _stringList(data['doseTimes']),
      doses: _doseList(data['doses']),
      mealOffset: (data['mealOffset'] as num?)?.toInt() ?? 0,
      mealScheduleEnabled: data['mealScheduleEnabled'] as bool? ?? false,
      mealTimes: _stringList(data['mealTimes']),
      checkIns: _checkInList(data['checkIns']),
      scheduleFrequency: data['scheduleFrequency'] as String? ?? 'daily',
      customIntervalDays: (data['customIntervalDays'] as num?)?.toInt() ?? 1,
      scheduleStartDate: (data['scheduleStartDate'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
      isActive: true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Medication copyWith({
    String? id,
    String? medicineName,
    String? medicineType,
    String? powerValue,
    String? powerUnit,
    String? languageCode,
    String? formula,
    String? companyName,
    String? imagePath,
    String? imageBytesBase64,
    String? backupImageUrl,
    String? dose,
    int? durationDays,
    String? timeOfDay,
    List<String>? doseTimes,
    List<MedicationDose>? doses,
    int? mealOffset,
    bool? mealScheduleEnabled,
    List<String>? mealTimes,
    List<MedicationCheckIn>? checkIns,
    String? scheduleFrequency,
    int? customIntervalDays,
    DateTime? scheduleStartDate,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      medicineType: medicineType ?? this.medicineType,
      powerValue: powerValue ?? this.powerValue,
      powerUnit: powerUnit ?? this.powerUnit,
      languageCode: languageCode ?? this.languageCode,
      formula: formula ?? this.formula,
      companyName: companyName ?? this.companyName,
      imagePath: imagePath ?? this.imagePath,
      imageBytesBase64: imageBytesBase64 ?? this.imageBytesBase64,
      backupImageUrl: backupImageUrl ?? this.backupImageUrl,
      dose: dose ?? this.dose,
      durationDays: durationDays ?? this.durationDays,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      doseTimes: doseTimes ?? this.doseTimes,
      doses: doses ?? this.doses,
      mealOffset: mealOffset ?? this.mealOffset,
      mealScheduleEnabled: mealScheduleEnabled ?? this.mealScheduleEnabled,
      mealTimes: mealTimes ?? this.mealTimes,
      checkIns: checkIns ?? this.checkIns,
      scheduleFrequency: scheduleFrequency ?? this.scheduleFrequency,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      scheduleStartDate: scheduleStartDate ?? this.scheduleStartDate,
      notes: notes ?? this.notes,
      isActive: true,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String? _cloudImageValue(String? imageUrlOverride) {
    final candidate = imageUrlOverride ?? backupImageUrl ?? imagePath;
    if (candidate == null || candidate.isEmpty) {
      return null;
    }
    return candidate.startsWith('http') ? candidate : null;
  }

  static List<String> _stringList(dynamic value) {
    return (value as List<dynamic>? ?? const <dynamic>[])
        .whereType<String>()
        .toList(growable: false);
  }

  static List<MedicationDose> _doseList(dynamic value) {
    return (value as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => MedicationDose.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static List<MedicationCheckIn> _checkInList(dynamic value) {
    return (value as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map(
          (item) => MedicationCheckIn.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }
}

DateTime? _dateTimeOrNull(dynamic value) {
  return value is String ? DateTime.tryParse(value) : null;
}
