import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/create_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/forget_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/get_passphrase_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

import 'support/passphrase_wallet_harness.dart';

void main() {
  late FakeWalletFacade wallets;
  late KeychainManifestFacade manifest;
  late FaultInjectingManifestRepository manifestRepository;
  late GetPassphraseWalletsUsecase getWallets;
  late ForgetPassphraseWalletUsecase usecase;

  Future<List<PassphraseWalletRecord>> records() async =>
      (await getWallets.execute()
              as Ok<List<PassphraseWalletRecord>, PassphraseWalletFailure>)
          .value;

  setUp(() async {
    wallets = FakeWalletFacade();
    final built = buildManifest();
    manifest = built.facade;
    manifestRepository = built.repository;
    final seedAndSettings = fakeSeedAndSettings();
    getWallets = GetPassphraseWalletsUsecase(
      seedAndSettings.seed,
      seedAndSettings.settings,
      manifest,
    );
    usecase = ForgetPassphraseWalletUsecase(wallets, manifest);

    // Start from a wallet the app created and loaded, the state Forget acts on.
    await CreatePassphraseWalletUsecase(manifest, wallets).execute(
      fakePreparation(),
      mountGeneration: wallets.beginPassphraseWalletMount(),
      label: 'Vault',
    );
    wallets.events.clear();
  });

  tearDown(() async {
    await wallets.dispose();
    await manifestRepository.dispose();
  });

  test('locks, deletes the cache, then the record — in that order', () async {
    final wallet = (await records()).single;

    expect(
      await usecase.execute(wallet),
      isA<Ok<void, PassphraseWalletFailure>>(),
    );

    // Decision 6: an interruption at any point here leaves a locked card, never
    // a wallet still on Home.
    expect(wallets.events, ['unload', 'deleteProjection:wallet']);
    expect(wallets.loadedWalletId, isNull);
    expect(await records(), isEmpty);
  });

  test('does not unload a wallet that was not loaded', () async {
    wallets.unloadPrivateWalletSession();
    wallets.events.clear();

    await usecase.execute((await records()).single);

    expect(wallets.events, ['deleteProjection:wallet']);
  });

  test('an interrupted forget leaves a retryable locked card', () async {
    final wallet = (await records()).single;
    manifestRepository.failRemove = true;

    final result = await usecase.execute(wallet);

    expect(
      result,
      isA<Err<void, PassphraseWalletFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<PassphraseWalletManifestFailure>(),
      ),
    );
    // The cache is gone and the record is not: a locked card the user can
    // forget again, and nothing left for Home to show.
    expect(wallets.events, ['unload', 'deleteProjection:wallet']);
    expect(wallets.loadedWalletId, isNull);
    expect((await records()).single.walletId, 'wallet');

    manifestRepository.failRemove = false;
    expect(
      await usecase.execute(wallet),
      isA<Ok<void, PassphraseWalletFailure>>(),
    );
    expect(await records(), isEmpty);
  });

  test(
    'a failed cache deletion keeps the record and touches nothing else',
    () async {
      wallets.deleteError = Exception('storage is gone');
      final wallet = (await records()).single;

      final result = await usecase.execute(wallet);

      expect(
        result,
        isA<Err<void, PassphraseWalletFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<PassphraseWalletStorageFailure>(),
        ),
      );
      expect((await records()).single.walletId, 'wallet');
    },
  );

  test('the record is gone before the wallet could reappear on Home', () async {
    await usecase.execute((await records()).single);

    // Nothing to re-derive a Home entry from: the projection went first and the
    // record is gone, so a later read finds no passphrase wallet at all.
    expect(await records(), isEmpty);
    expect(wallets.loadedWalletId, isNull);
  });
}
