import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

// Obviously-fake fixtures: the all-zero BIP39 test vector and a joke passphrase.
const _mnemonic =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const _passphrase = 'hunter2';

void main() {
  const bdkWallet = WalletModel.privateBdk(
    id: 'private-bdk',
    scriptType: ScriptType.bip84,
    mnemonic: _mnemonic,
    passphrase: _passphrase,
    isTestnet: true,
  );
  const lwkWallet = WalletModel.privateLwk(
    id: 'private-lwk',
    mnemonic: _mnemonic,
    isTestnet: true,
  );

  Matcher redacted() =>
      allOf(isNot(contains(_mnemonic)), isNot(contains(_passphrase)));

  group('private BDK wallet model', () {
    test('toString redacts the mnemonic and passphrase', () {
      expect(bdkWallet.toString(), redacted());
      expect(bdkWallet.toString(), contains('mnemonic: <redacted>'));
      expect(bdkWallet.toString(), contains('passphrase: <redacted>'));
      // Non-secret fields stay visible so the dump is still useful.
      expect(bdkWallet.toString(), contains('id: private-bdk'));
    });

    test('string interpolation and collection dumps stay redacted', () {
      expect('$bdkWallet', redacted());
      expect([bdkWallet].toString(), redacted());
      expect({'wallet': bdkWallet}.toString(), redacted());
    });

    test('a thrown error wrapping the model stays redacted', () {
      Object? caught;
      try {
        throw StateError('failed to sign with $bdkWallet');
      } catch (e) {
        caught = e;
      }
      expect(caught.toString(), redacted());

      try {
        throw ArgumentError.value(bdkWallet, 'wallet', 'unsupported');
      } catch (e) {
        caught = e;
      }
      expect(caught.toString(), redacted());
    });
  });

  group('private LWK wallet model', () {
    test('toString redacts the mnemonic', () {
      expect(lwkWallet.toString(), redacted());
      expect(lwkWallet.toString(), contains('mnemonic: <redacted>'));
      expect(lwkWallet.toString(), contains('id: private-lwk'));
    });

    test('string interpolation and collection dumps stay redacted', () {
      expect('$lwkWallet', redacted());
      expect([lwkWallet].toString(), redacted());
      expect({'wallet': lwkWallet}.toString(), redacted());
    });

    test('a thrown error wrapping the model stays redacted', () {
      Object? caught;
      try {
        throw StateError('failed to sign with $lwkWallet');
      } catch (e) {
        caught = e;
      }
      expect(caught.toString(), redacted());
    });
  });

  test('private models do not expose secrets through equality', () {
    // Value equality over a mnemonic turns `==` into an oracle for guessing it,
    // so the private variants deliberately keep identity equality.
    final a = WalletModel.privateBdk(
      id: 'same',
      scriptType: ScriptType.bip84,
      mnemonic: _mnemonic,
      passphrase: _passphrase,
      isTestnet: true,
    );
    final b = WalletModel.privateBdk(
      id: 'same',
      scriptType: ScriptType.bip84,
      mnemonic: _mnemonic,
      passphrase: _passphrase,
      isTestnet: true,
    );
    expect(a == b, isFalse);
    expect(a == a, isTrue);
  });

  test('public models keep value equality and a full toString', () {
    const a = WalletModel.publicBdk(
      id: 'public-bdk',
      externalDescriptor: 'wpkh(external)',
      internalDescriptor: 'wpkh(internal)',
      isTestnet: true,
    );
    const b = WalletModel.publicBdk(
      id: 'public-bdk',
      externalDescriptor: 'wpkh(external)',
      internalDescriptor: 'wpkh(internal)',
      isTestnet: true,
    );
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
    expect(a.toString(), contains('wpkh(external)'));

    const lwk = WalletModel.publicLwk(
      id: 'public-lwk',
      combinedCtDescriptor: 'ct(slip77(00),elwpkh(xpub))',
      isTestnet: true,
    );
    expect(
      lwk,
      equals(
        const WalletModel.publicLwk(
          id: 'public-lwk',
          combinedCtDescriptor: 'ct(slip77(00),elwpkh(xpub))',
          isTestnet: true,
        ),
      ),
    );
    expect(lwk.toString(), contains('ct(slip77(00),elwpkh(xpub))'));
  });
}
