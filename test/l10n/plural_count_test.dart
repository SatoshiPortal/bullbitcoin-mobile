import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Locales whose intl "one" case also holds 0, so a literal 1 in a =1/one
// branch is shown for a count of 0.
const _zeroIsOne = [
  'fr',
  'pt',
  'pt_BR',
  'hi',
  'hi_Latn',
  'bn',
  'as',
  'fa',
  'hy',
];

final _oneBranch = RegExp(r'(?:=1|\bone)\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}');
final _literalOne = RegExp('[1\u06F1\u0661\u09E7]');

void main() {
  group('a plural branch prints the count it was given', () {
    for (final locale in _zeroIsOne) {
      test('$locale has no literal 1 in a =1/one branch', () {
        final arb =
            jsonDecode(File('localization/app_$locale.arb').readAsStringSync())
                as Map<String, dynamic>;
        final offenders = [
          for (final MapEntry(:key, :value) in arb.entries)
            if (!key.startsWith('@') &&
                value is String &&
                value.contains('plural,') &&
                !value.contains('=0{') &&
                _oneBranch
                    .allMatches(value)
                    .any((m) => _literalOne.hasMatch(m.group(1)!)))
              key,
        ];

        expect(offenders, isEmpty);
      });
    }

    for (final locale in ['fr', 'pt', 'fa', 'bn', 'as']) {
      test('$locale shows 0 coins as 0', () {
        final loc = lookupAppLocalizations(Locale(locale));

        for (final text in [
          loc.walletCoinsEntryUtxoCount(0),
          loc.coinsSummaryCoinsCount(0),
          loc.coinsSelectedCount(0),
        ]) {
          expect(text, contains('0'));
          expect(text, isNot(contains(_literalOne)));
        }
      });
    }

    test('English is unchanged', () {
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(loc.walletCoinsEntryUtxoCount(0), '0 UTXOs');
      expect(loc.walletCoinsEntryUtxoCount(1), '1 UTXO');
    });
  });
}
