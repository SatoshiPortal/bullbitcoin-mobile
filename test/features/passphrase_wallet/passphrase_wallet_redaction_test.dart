import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_deriver.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/passphrase_wallet_harness.dart';

// The same obviously-fake passphrase the wallet model redaction test uses.
const _passphrase = 'hunter2';

void main() {
  Matcher redacted() =>
      allOf(isNot(contains(_passphrase)), isNot(contains(testMnemonic.first)));

  final preparation = fakePreparation(passphrase: _passphrase);
  final derivation = PassphraseWalletDerivation(
    walletId: 'wallet',
    combinedPublicDescriptor: firstDescriptor,
    seed: fakeSeed(_passphrase),
  );

  test('a candidate redacts its material everywhere it can be printed', () {
    final candidate = preparation.candidate;
    expect(candidate.toString(), redacted());
    expect('$candidate', redacted());
    expect([candidate].toString(), redacted());
    expect({'candidate': candidate}.toString(), redacted());

    Object? caught;
    try {
      throw StateError('failed to mount $candidate');
    } catch (error) {
      caught = error;
    }
    expect(caught.toString(), redacted());
  });

  test('a preparation redacts the candidate it wraps', () {
    expect(preparation.toString(), redacted());
    expect([preparation].toString(), redacted());
    expect(
      ArgumentError.value(preparation, 'preparation', 'bad').toString(),
      redacted(),
    );
  });

  test('a derivation redacts the seed it hands over', () {
    expect(derivation.toString(), redacted());
    expect([derivation].toString(), redacted());
    expect(StateError('could not use $derivation').toString(), redacted());
  });

  test('a scan failure carries no descriptor', () {
    const failure = PassphraseWalletScanException();
    expect(failure.toString(), isNot(contains(firstDescriptor)));
    expect(failure.toString(), 'PassphraseWalletScanException');
  });
}
