import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_unlock_session.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MnemonicSeed seed(String passphrase) =>
      Seed.mnemonic(
            mnemonicWords: const ['abandon'],
            passphrase: passphrase,
            bytes: Uint8List.fromList([1]),
            masterFingerprint: '00000001',
          )
          as MnemonicSeed;

  test('keeps only one unlocked wallet and clears it on lock', () async {
    final session = WalletUnlockSession();
    addTearDown(session.close);

    final first = seed('first secret');
    expect(
      session.unlockIfCurrent(
        generation: session.beginMount(),
        walletId: 'first',
        seed: first,
      ),
      isTrue,
    );
    expect(session.seedFor('first').passphrase, 'first secret');

    final second = seed('second secret');
    expect(
      session.unlockIfCurrent(
        generation: session.beginMount(),
        walletId: 'second',
        seed: second,
      ),
      isTrue,
    );
    expect(first.bytes, everyElement(0));
    expect(session.isUnlocked('first'), isFalse);
    expect(
      () => session.seedFor('first'),
      throwsA(isA<PassphraseWalletLockedException>()),
    );
    expect(session.seedFor('second').passphrase, 'second secret');

    expect(session.lock(), isTrue);
    expect(second.bytes, everyElement(0));
    expect(session.unlockedWalletId, isNull);
    expect(
      () => session.seedFor('second'),
      throwsA(isA<PassphraseWalletLockedException>()),
    );
    expect(session.lock(), isFalse);
  });

  test(
    'a cancelled or superseded mount cannot load private material',
    () async {
      final session = WalletUnlockSession();
      addTearDown(session.close);
      final cancelled = seed('cancelled');
      final oldGeneration = session.beginMount();

      session.cancelMount();

      expect(
        session.unlockIfCurrent(
          generation: oldGeneration,
          walletId: 'cancelled',
          seed: cancelled,
        ),
        isFalse,
      );
      expect(session.unlockedWalletId, isNull);
      expect(cancelled.bytes, everyElement(isNot(0)));

      final current = seed('current');
      final currentGeneration = session.beginMount();
      expect(
        session.unlockIfCurrent(
          generation: currentGeneration,
          walletId: 'current',
          seed: current,
        ),
        isTrue,
      );

      session.cancelMount();

      expect(session.seedFor('current').passphrase, 'current');
    },
  );

  test(
    'locking an empty session still invalidates an in-flight mount',
    () async {
      final session = WalletUnlockSession();
      addTearDown(session.close);
      final material = seed('late');
      final generation = session.beginMount();

      expect(session.lock(), isFalse);

      expect(
        session.unlockIfCurrent(
          generation: generation,
          walletId: 'late',
          seed: material,
        ),
        isFalse,
      );
    },
  );
}
