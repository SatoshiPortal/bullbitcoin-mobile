import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/unlock_known_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

import 'support/passphrase_wallet_harness.dart';

void main() {
  late FakeWalletFacade wallets;
  late UnlockKnownPassphraseWalletUsecase usecase;

  setUp(() {
    wallets = FakeWalletFacade();
    usecase = UnlockKnownPassphraseWalletUsecase(wallets);
  });

  tearDown(() => wallets.dispose());

  test('mounts the known wallet under its stored label', () async {
    final preparation = fakePreparation(known: fakeRecord(label: 'Vault'));
    final seed = preparation.candidate.seed;

    final result = await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
    );

    expect(result, isA<Ok<void, PassphraseWalletFailure>>());
    expect(wallets.events, ['mount:wallet:Vault']);
    expect(wallets.loadedWalletId, 'wallet');
    // The session owns the material now, so it must still be usable.
    expect(preparation.candidate.isHeld, isFalse);
    expect(seed.bytes, everyElement(isNot(0)));
  });

  test('refuses a preparation with no known wallet', () async {
    final preparation = fakePreparation();
    final seed = preparation.candidate.seed;

    final result = await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
    );

    expect(
      result,
      isA<Err<void, PassphraseWalletFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<PassphraseWalletConflictFailure>(),
      ),
    );
    expect(wallets.events, isEmpty);
    expect(seed.bytes, everyElement(0));
  });

  test('refuses a known record whose descriptor differs', () async {
    // A four-byte fingerprint or a wallet id that happens to line up is not
    // identity; the combined descriptor is (spec 6.5).
    final preparation = fakePreparation(
      record: fakeRecord(descriptor: firstDescriptor),
      known: fakeRecord(descriptor: secondDescriptor),
    );
    final seed = preparation.candidate.seed;

    final result = await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
    );

    expect(
      result,
      isA<Err<void, PassphraseWalletFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<PassphraseWalletConflictFailure>(),
      ),
    );
    expect(wallets.events, isEmpty);
    expect(seed.bytes, everyElement(0));
  });

  test('clears the material when the mount conflicts', () async {
    wallets.mountStatus = WalletDefinitionRestoreStatus.conflict;
    final preparation = fakePreparation(known: fakeRecord());
    final seed = preparation.candidate.seed;

    expect(
      await usecase.execute(
        preparation,
        mountGeneration: wallets.beginPassphraseWalletMount(),
      ),
      isA<Err<void, PassphraseWalletFailure>>(),
    );
    expect(seed.bytes, everyElement(0));
    expect(wallets.loadedWalletId, isNull);
  });
}
