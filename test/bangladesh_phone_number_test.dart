import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/features/auth/domain/bangladesh_phone_number.dart';

void main() {
  group('BangladeshPhoneNumber.normalize', () {
    const normalized = '+8801712345678';

    for (final input in <String>[
      '+8801712345678',
      '8801712345678',
      '008801712345678',
      '01712345678',
      '1712345678',
      '+880 17 1234 5678',
      '01712-345678',
      '(017) 1234 5678',
      '০১৭১২৩৪৫৬৭৮',
    ]) {
      test('normalizes $input', () {
        expect(BangladeshPhoneNumber.normalize(input), normalized);
      });
    }

    for (final input in <String>[
      '',
      '12345',
      '+8801212345678',
      '+880171234567',
      '+88017123456789',
      'not-a-number',
    ]) {
      test('rejects $input', () {
        expect(
          () => BangladeshPhoneNumber.normalize(input),
          throwsFormatException,
        );
      });
    }
  });
}
