import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a plural branch prints the count it was given', () {
    test('French shows 0 coins as 0, not 1', () {
      final loc = lookupAppLocalizations(const Locale('fr'));

      expect(loc.walletCoinsEntryUtxoCount(0), '0 UTXO');
      expect(loc.coinsSummaryCoinsCount(0), '0 pièce');
      expect(loc.walletCoinsEntryUtxoCount(1), '1 UTXO');
      expect(loc.walletCoinsEntryUtxoCount(2), '2 UTXOs');
    });

    test('Portuguese shows 0 coins as 0, not 1', () {
      final loc = lookupAppLocalizations(const Locale('pt'));

      expect(loc.coinsSummaryCoinsCount(0), '0 moeda');
    });

    test('English is unchanged', () {
      final loc = lookupAppLocalizations(const Locale('en'));

      expect(loc.walletCoinsEntryUtxoCount(0), '0 UTXOs');
      expect(loc.walletCoinsEntryUtxoCount(1), '1 UTXO');
    });
  });
}
