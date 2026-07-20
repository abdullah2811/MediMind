import 'package:cloud_firestore/cloud_firestore.dart';

class Medication {
  const Medication({
    required this.id,
    required this.medicineName,
    required this.dose,
    required this.durationDays,
    required this.timeOfDay,
    this.doseTimes = const <String>[],
    required this.mealOffset,
    this.formula,
    this.companyName,
    this.imagePath,
    this.imageBytesBase64,
    this.notes,
    this.backupImageUrl,
    required this.isActive,
    required this.updatedAt,
  });

  final String id;
  final String medicineName;
  final String? formula;
  final String? companyName;
  final String? imagePath;
  final String? imageBytesBase64;
  final String? backupImageUrl;
  final String dose;
  final int durationDays;
  final String timeOfDay;
  final List<String> doseTimes;
  final int mealOffset;
  final String? notes;
  final bool isActive;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'medicineName': medicineName,
    'formula': formula,
    'companyName': companyName,
    'imagePath': imagePath,
    'imageBytesBase64': imageBytesBase64,
    'backupImageUrl': backupImageUrl,
    'dose': dose,
    'durationDays': durationDays,
    'timeOfDay': timeOfDay,
    'doseTimes': doseTimes,
    'mealOffset': mealOffset,
    'notes': notes,
    'isActive': isActive,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    id: json['id'] as String,
    medicineName: json['medicineName'] as String,
    formula: json['formula'] as String?,
    companyName: json['companyName'] as String?,
    imagePath: json['imagePath'] as String?,
    imageBytesBase64: json['imageBytesBase64'] as String?,
    backupImageUrl: json['backupImageUrl'] as String?,
    dose: (json['dose'] as String?) ?? '',
    durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
    timeOfDay: json['timeOfDay'] as String,
    doseTimes: (json['doseTimes'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item as String)
        .toList(growable: false),
    mealOffset: (json['mealOffset'] as num).toInt(),
    notes: json['notes'] as String?,
    isActive: json['isActive'] as bool? ?? true,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, dynamic> toFirestore({
    required String uid,
    String? imageUrlOverride,
  }) => <String, dynamic>{
    'reminderId': id,
    'uid': uid,
    'medicineName': medicineName,
    'formula': formula,
    'companyName': companyName,
    'dose': dose,
    'durationDays': durationDays,
    'timeOfDay': timeOfDay,
    'doseTimes': doseTimes,
    'mealOffset': mealOffset,
    'imagePath': _cloudImageValue(imageUrlOverride),
    'notes': notes,
    'isActive': isActive,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Medication.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return Medication(
      id: data['reminderId'] as String? ?? snapshot.id,
      medicineName: data['medicineName'] as String? ?? '',
      formula: data['formula'] as String?,
      companyName: data['companyName'] as String?,
      imagePath: data['imagePath'] as String?,
      backupImageUrl: data['imagePath'] as String?,
      imageBytesBase64: null,
      dose: data['dose'] as String? ?? '',
      durationDays: (data['durationDays'] as num?)?.toInt() ?? 0,
      timeOfDay: data['timeOfDay'] as String? ?? '',
      doseTimes: (data['doseTimes'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as String)
          .toList(growable: false),
      mealOffset: (data['mealOffset'] as num?)?.toInt() ?? 0,
      notes: data['notes'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Medication copyWith({
    String? id,
    String? medicineName,
    String? formula,
    String? companyName,
    String? imagePath,
    String? imageBytesBase64,
    String? backupImageUrl,
    String? dose,
    int? durationDays,
    String? timeOfDay,
    List<String>? doseTimes,
    int? mealOffset,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      medicineName: medicineName ?? this.medicineName,
      formula: formula ?? this.formula,
      companyName: companyName ?? this.companyName,
      imagePath: imagePath ?? this.imagePath,
      imageBytesBase64: imageBytesBase64 ?? this.imageBytesBase64,
      backupImageUrl: backupImageUrl ?? this.backupImageUrl,
      dose: dose ?? this.dose,
      durationDays: durationDays ?? this.durationDays,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      doseTimes: doseTimes ?? this.doseTimes,
      mealOffset: mealOffset ?? this.mealOffset,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
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
}
