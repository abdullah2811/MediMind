import 'dart:convert';
import 'dart:typed_data';

import '../models/medication.dart';

Uint8List? medicationImageBytes(Medication medication) {
  final encoded = medication.imageBytesBase64;
  if (encoded == null || encoded.isEmpty) {
    return null;
  }
  try {
    return base64Decode(encoded);
  } on FormatException {
    return null;
  }
}

String? medicationNetworkImageUrl(Medication medication) {
  final candidates = <String?>[medication.backupImageUrl, medication.imagePath];
  for (final candidate in candidates) {
    if (candidate != null &&
        (candidate.startsWith('https://') || candidate.startsWith('http://'))) {
      return candidate;
    }
  }
  return null;
}
