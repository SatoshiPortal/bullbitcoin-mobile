import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final txId = 'a' * 64;

  test('preserves exact wallet attribution and exposes its outpoint', () {
    const walletId = 'elwpkh([0f36572d/84h/1h/0h])';
    final freeze = FrozenWalletOutpoint(
      walletId: walletId,
      txId: txId,
      vout: 7,
    );

    expect(freeze.walletId, walletId);
    expect(freeze.isAttributed, isTrue);
    expect(freeze.outpoint, (txId: txId, vout: 7));
  });

  test('an empty wallet id is valid and remains unattributed', () {
    final freeze = FrozenWalletOutpoint(walletId: '', txId: txId, vout: 0);

    expect(freeze.walletId, isEmpty);
    expect(freeze.isAttributed, isFalse);
  });

  test('normalizes a hexadecimal transaction id', () {
    final freeze = FrozenWalletOutpoint(
      walletId: 'wallet',
      txId: 'A' * 64,
      vout: 1,
    );

    expect(freeze.txId, 'a' * 64);
  });

  test('rejects malformed outpoints before they reach backup records', () {
    expect(
      () => FrozenWalletOutpoint(walletId: 'wallet', txId: 'abcd', vout: 0),
      throwsArgumentError,
    );
    expect(
      () => FrozenWalletOutpoint(walletId: 'wallet', txId: txId, vout: -1),
      throwsArgumentError,
    );
    expect(
      () => FrozenWalletOutpoint(
        walletId: 'wallet',
        txId: txId,
        vout: 0x100000000,
      ),
      throwsArgumentError,
    );
  });
}
