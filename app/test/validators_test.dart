import 'package:flutter_test/flutter_test.dart';
import 'package:safetrip/core/utils/validators.dart';

void main() {
  group('Validators.email', () {
    test('accepts a valid address', () {
      expect(Validators.email('amine.bs@univ.tn'), isNull);
    });

    test('rejects empty and malformed values', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('amine@'), isNotNull);
      expect(Validators.email('pas-un-email'), isNotNull);
    });
  });

  group('Validators.phone', () {
    test('accepts Tunisian numbers with or without prefix', () {
      expect(Validators.phone('20 123 456'), isNull);
      expect(Validators.phone('+21698123456'), isNull);
    });

    test('rejects wrong lengths', () {
      expect(Validators.phone('1234'), isNotNull);
      expect(Validators.phone('012345678'), isNotNull);
    });

    test('normalizes every accepted form to the same key', () {
      expect(Validators.normalizePhone('20 123 456'), '+21620123456');
      expect(Validators.normalizePhone('20.123-456'), '+21620123456');
      expect(Validators.normalizePhone('+216 20 123 456'), '+21620123456');
    });
  });

  group('Validators.newPassword', () {
    test('requires 8 chars with letters and digits', () {
      expect(Validators.newPassword('abc'), isNotNull);
      expect(Validators.newPassword('abcdefgh'), isNotNull);
      expect(Validators.newPassword('12345678'), isNotNull);
      expect(Validators.newPassword('Safe2026'), isNull);
    });
  });
}
