import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/core/theme/app_theme.dart';

void main() {
  test('bold semantic text roles match in English and Bangla', () {
    final english = buildAppTheme(const Locale('en'));
    final bangla = buildAppTheme(const Locale('bn'));

    expect(english.textTheme.titleLarge?.fontWeight, FontWeight.w800);
    expect(
      english.textTheme.titleLarge?.fontWeight,
      bangla.textTheme.titleLarge?.fontWeight,
    );
    expect(english.textTheme.labelLarge?.fontWeight, FontWeight.w800);
    expect(
      english.textTheme.labelLarge?.fontWeight,
      bangla.textTheme.labelLarge?.fontWeight,
    );
    expect(english.textTheme.bodyLarge?.fontWeight, FontWeight.w700);
    expect(
      english.textTheme.bodyLarge?.fontWeight,
      bangla.textTheme.bodyLarge?.fontWeight,
    );
    expect(english.textTheme.bodyMedium?.fontWeight, FontWeight.w700);
    expect(
      english.textTheme.bodyMedium?.fontWeight,
      bangla.textTheme.bodyMedium?.fontWeight,
    );
    expect(
      english.inputDecorationTheme.labelStyle?.fontWeight,
      FontWeight.w700,
    );
    expect(
      english.inputDecorationTheme.floatingLabelStyle?.fontWeight,
      FontWeight.w800,
    );
    expect(english.listTileTheme.titleTextStyle?.fontWeight, FontWeight.w700);
    expect(english.dialogTheme.titleTextStyle?.fontWeight, FontWeight.w800);
    expect(english.snackBarTheme.contentTextStyle?.fontWeight, FontWeight.w700);
  });
}
