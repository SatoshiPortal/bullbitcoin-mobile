import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/create_passphrase_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok;

import 'support/passphrase_wallet_harness.dart';

void main() {
  late FakeWalletFacade wallets;
  late KeychainManifestFacade manifest;
  late FaultInjectingManifestRepository manifestRepository;
  late CreatePassphraseWalletUsecase usecase;

  Future<List<KeychainManifestWallet>> storedWallets() async {
    final read = await manifest.readManifest(Fingerprint(parentFingerprint));
    return [
      for (final entry
          in (read as Ok<KeychainManifest, KeychainManifestFailure>)
              .value
              .entries)
        ...entry.materializations.whereType<KeychainManifestWallet>(),
    ];
  }

  setUp(() {
    wallets = FakeWalletFacade();
    final built = buildManifest();
    manifest = built.facade;
    manifestRepository = built.repository;
    usecase = CreatePassphraseWalletUsecase(manifest, wallets);
  });

  tearDown(() async {
    await wallets.dispose();
    await manifestRepository.dispose();
  });

  test('records the manifest before mounting, and mounts once', () async {
    final preparation = fakePreparation();

    final result = await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
      label: '  Savings  ',
      hint: 'the usual one',
    );

    expect(
      result,
      isA<Ok<PassphraseWalletOpenStatus, PassphraseWalletFailure>>().having(
        (value) => value.value,
        'status',
        PassphraseWalletOpenStatus.opened,
      ),
    );
    // The record exists before the wallet does, so an interruption between them
    // leaves something recoverable.
    final stored = await storedWallets();
    expect(stored.single.walletId, 'wallet');
    expect(stored.single.label, 'Savings');
    expect(stored.single.descriptor, firstDescriptor);
    expect(wallets.events, ['mount:wallet:Savings']);
    expect(wallets.loadedWalletId, 'wallet');
  });

  test('the wallet session owns the material after a successful mount', () async {
    final preparation = fakePreparation();
    final seed = preparation.candidate.seed;

    await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
    );

    expect(preparation.candidate.isHeld, isFalse);
    expect(seed.bytes, everyElement(isNot(0)));

    // A later cancel path must not zero bytes the loaded wallet is signing with.
    preparation.clear();
    expect(seed.bytes, everyElement(isNot(0)));
  });

  test('does not mount when the manifest write fails', () async {
    manifestRepository.failUpsert = true;
    final preparation = fakePreparation();
    final seed = preparation.candidate.seed;

    final result = await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
    );

    expect(
      result,
      isA<Err<PassphraseWalletOpenStatus, PassphraseWalletFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<PassphraseWalletManifestFailure>(),
      ),
    );
    expect(wallets.events, isEmpty);
    expect(seed.bytes, everyElement(0));
  });

  test(
    'keeps the saved record and clears the material when mounting fails',
    () async {
      wallets.mountError = Exception('storage is gone');
      final preparation = fakePreparation();
      final seed = preparation.candidate.seed;

      final result = await usecase.execute(
        preparation,
        mountGeneration: wallets.beginPassphraseWalletMount(),
      );

      expect(
        result,
        isA<Ok<PassphraseWalletOpenStatus, PassphraseWalletFailure>>().having(
          (value) => value.value,
          'status',
          PassphraseWalletOpenStatus.savedButNotOpened,
        ),
      );
      expect((await storedWallets()).single.walletId, 'wallet');
      expect(seed.bytes, everyElement(0));
    },
  );

  test('a hint over the boundary persists nothing', () async {
    final preparation = fakePreparation();
    final seed = preparation.candidate.seed;

    final result = await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
      hint: 'x' * (KeychainManifestEntry.maxDescriptionLength + 1),
    );

    expect(
      result,
      isA<Err<PassphraseWalletOpenStatus, PassphraseWalletFailure>>(),
    );
    expect(await storedWallets(), isEmpty);
    expect(wallets.events, isEmpty);
    expect(seed.bytes, everyElement(0));
  });

  test('a hint exactly at the boundary is accepted', () async {
    final result = await usecase.execute(
      fakePreparation(),
      mountGeneration: wallets.beginPassphraseWalletMount(),
      hint: 'x' * KeychainManifestEntry.maxDescriptionLength,
    );

    expect(
      result,
      isA<Ok<PassphraseWalletOpenStatus, PassphraseWalletFailure>>(),
    );
  });

  test('an empty label is stored as no label at all', () async {
    await usecase.execute(
      fakePreparation(),
      mountGeneration: wallets.beginPassphraseWalletMount(),
      label: '   ',
    );

    expect((await storedWallets()).single.label, isNull);
    expect(wallets.events, ['mount:wallet:null']);
  });

  test('refuses to create a wallet the app already knows', () async {
    final preparation = fakePreparation(known: fakeRecord());
    final seed = preparation.candidate.seed;

    final result = await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
    );

    expect(
      result,
      isA<Err<PassphraseWalletOpenStatus, PassphraseWalletFailure>>().having(
        (value) => value.failure,
        'failure',
        isA<PassphraseWalletConflictFailure>(),
      ),
    );
    expect(await storedWallets(), isEmpty);
    expect(seed.bytes, everyElement(0));
  });

  test('a mount conflict clears the material', () async {
    wallets.mountStatus = WalletDefinitionRestoreStatus.conflict;
    final preparation = fakePreparation();
    final seed = preparation.candidate.seed;

    final result = await usecase.execute(
      preparation,
      mountGeneration: wallets.beginPassphraseWalletMount(),
    );

    expect(
      result,
      isA<Ok<PassphraseWalletOpenStatus, PassphraseWalletFailure>>().having(
        (value) => value.value,
        'status',
        PassphraseWalletOpenStatus.savedButNotOpened,
      ),
    );
    expect(seed.bytes, everyElement(0));
    expect(wallets.loadedWalletId, isNull);
  });
}
