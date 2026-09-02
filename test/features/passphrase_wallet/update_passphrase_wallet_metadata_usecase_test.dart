import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/create_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/get_passphrase_wallets_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/update_passphrase_wallet_metadata_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

import 'support/passphrase_wallet_harness.dart';

void main() {
  late FakeWalletFacade wallets;
  late KeychainManifestFacade manifest;
  late FaultInjectingManifestRepository manifestRepository;
  late GetPassphraseWalletsUsecase getWallets;
  late UpdatePassphraseWalletMetadataUsecase usecase;

  Future<PassphraseWalletRecord> stored() async =>
      (await getWallets.execute()
              as Ok<List<PassphraseWalletRecord>, PassphraseWalletFailure>)
          .value
          .single;

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
    usecase = UpdatePassphraseWalletMetadataUsecase(manifest, wallets);
    await CreatePassphraseWalletUsecase(manifest, wallets).execute(
      fakePreparation(),
      mountGeneration: wallets.beginPassphraseWalletMount(),
      label: 'Vault',
      hint: 'the first one',
    );
    wallets.events.clear();
  });

  tearDown(() async {
    await wallets.dispose();
    await manifestRepository.dispose();
  });

  test('a hint edit writes the manifest and projects nothing', () async {
    final result = await usecase.execute(
      await stored(),
      hint: const KeychainManifestEdit('a better reminder'),
    );

    expect(
      result,
      isA<Ok<PassphraseWalletMetadataStatus, PassphraseWalletFailure>>().having(
        (value) => value.value,
        'status',
        PassphraseWalletMetadataStatus.updated,
      ),
    );
    expect((await stored()).hint, 'a better reminder');
    // The hint lives in the manifest alone; the wallet never hears about it.
    expect(wallets.events, isEmpty);
  });

  test('a hint can be removed', () async {
    await usecase.execute(
      await stored(),
      hint: const KeychainManifestEdit(null),
    );

    expect((await stored()).hint, isNull);
  });

  test('a label edit writes the manifest first, then the projection', () async {
    final result = await usecase.execute(
      await stored(),
      label: const KeychainManifestEdit('  Savings  '),
    );

    expect(
      result,
      isA<Ok<PassphraseWalletMetadataStatus, PassphraseWalletFailure>>().having(
        (value) => value.value,
        'status',
        PassphraseWalletMetadataStatus.updated,
      ),
    );
    expect((await stored()).label, 'Savings');
    expect(wallets.events, ['updateLabel:wallet:Savings']);
  });

  test(
    'a failed projection keeps the manifest truth and asks for a remount',
    () async {
      wallets.labelError = Exception('wallet is not mounted');

      final result = await usecase.execute(
        await stored(),
        label: const KeychainManifestEdit('Savings'),
      );

      expect(
        result,
        isA<Ok<PassphraseWalletMetadataStatus, PassphraseWalletFailure>>()
            .having(
              (value) => value.value,
              'status',
              PassphraseWalletMetadataStatus.savedRemountNeeded,
            ),
      );
      // Decision 2: the manifest is canonical, so the edit did happen.
      expect((await stored()).label, 'Savings');
    },
  );

  test('a failed manifest write changes nothing at all', () async {
    manifestRepository.failLabelHint = true;

    final result = await usecase.execute(
      await stored(),
      label: const KeychainManifestEdit('Savings'),
      hint: const KeychainManifestEdit('another'),
    );

    expect(
      result,
      isA<Err<PassphraseWalletMetadataStatus, PassphraseWalletFailure>>()
          .having(
            (value) => value.failure,
            'failure',
            isA<PassphraseWalletManifestFailure>(),
          ),
    );
    expect((await stored()).label, 'Vault');
    expect((await stored()).hint, 'the first one');
    expect(wallets.events, isEmpty);
  });

  test(
    'a hint over the boundary is refused before anything is written',
    () async {
      final result = await usecase.execute(
        await stored(),
        hint: KeychainManifestEdit(
          'x' * (KeychainManifestEntry.maxDescriptionLength + 1),
        ),
      );

      expect(
        result,
        isA<Err<PassphraseWalletMetadataStatus, PassphraseWalletFailure>>(),
      );
      expect((await stored()).hint, 'the first one');
    },
  );

  test('a hint exactly at the boundary is accepted', () async {
    final hint = 'x' * KeychainManifestEntry.maxDescriptionLength;

    final result = await usecase.execute(
      await stored(),
      hint: KeychainManifestEdit(hint),
    );

    expect(
      result,
      isA<Ok<PassphraseWalletMetadataStatus, PassphraseWalletFailure>>(),
    );
    expect((await stored()).hint, hint);
  });
}
