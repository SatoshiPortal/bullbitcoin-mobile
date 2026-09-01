import 'dart:async';

import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/entities/passphrase_wallet.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/create_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/forget_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/get_passphrase_wallets_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/prepare_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/scan_passphrase_wallet_balance_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/unlock_known_passphrase_wallet_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/usecases/update_passphrase_wallet_metadata_usecase.dart';
import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_cubit.dart';
import 'package:bb_mobile/features/passphrase_wallet/presentation/passphrase_wallet_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok;

import 'support/passphrase_wallet_harness.dart';

void main() {
  late FakeWalletFacade wallets;
  late KeychainManifestFacade manifest;
  late FaultInjectingManifestRepository manifestRepository;
  late FakePassphraseWalletDeriver deriver;
  late FakePassphraseWalletScanner scanner;
  late PassphraseWalletCubit cubit;

  /// Puts a passphrase wallet in the manifest as if the user had created it,
  /// without loading it: a locked card on the next page load.
  Future<void> givenLockedWallet({
    required String walletId,
    required String descriptor,
    String? label,
    String? hint,
    int createdAt = 1,
  }) async {
    final saved = await manifest.recordWallet(
      parentFingerprint: Fingerprint(parentFingerprint),
      wallet: passphraseBinding(
        walletId: walletId,
        descriptor: descriptor,
        label: label,
        hint: hint,
        createdAt: createdAt,
      ),
    );
    expect(saved, isA<Ok<bool, KeychainManifestFailure>>());
  }

  setUp(() {
    wallets = FakeWalletFacade();
    final built = buildManifest();
    manifest = built.facade;
    manifestRepository = built.repository;
    deriver = FakePassphraseWalletDeriver({
      'known': (walletId: 'wallet-one', descriptor: firstDescriptor),
    });
    scanner = FakePassphraseWalletScanner(
      balances: {firstDescriptor: BigInt.from(1500)},
    );
    final seedAndSettings = fakeSeedAndSettings();
    final getWallets = GetPassphraseWalletsUsecase(
      seedAndSettings.seed,
      seedAndSettings.settings,
      manifest,
    );
    cubit = PassphraseWalletCubit(
      getWallets,
      PreparePassphraseWalletUsecase(
        seedAndSettings.seed,
        seedAndSettings.settings,
        getWallets,
        deriver,
      ),
      UnlockKnownPassphraseWalletUsecase(wallets),
      CreatePassphraseWalletUsecase(manifest, wallets),
      ForgetPassphraseWalletUsecase(wallets, manifest),
      UpdatePassphraseWalletMetadataUsecase(manifest, wallets),
      ScanPassphraseWalletBalanceUsecase(scanner),
      wallets,
    );
  });

  tearDown(() async {
    await cubit.close();
    await wallets.dispose();
    await manifestRepository.dispose();
  });

  group('loaded and locked', () {
    test('a card is locked until the catalog says otherwise', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );

      await cubit.load();

      expect(cubit.state.wallets.single.wallet.walletId, 'wallet-one');
      expect(cubit.state.isLoaded('wallet-one'), isFalse);
      expect(cubit.state.hasLoadedWallet, isFalse);
    });

    test('loading emits exactly one state transition', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      await cubit.load();
      final transitions = <PassphraseWalletState>[];
      final subscription = cubit.stream.listen(transitions.add);
      addTearDown(subscription.cancel);

      wallets.publishCatalog(['wallet-one']);
      await pumpEventQueue();

      expect(transitions, hasLength(1));
      expect(transitions.single.isLoaded('wallet-one'), isTrue);
    });

    test('unloading emits exactly one state transition', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      await cubit.load();
      wallets.publishCatalog(['wallet-one']);
      await pumpEventQueue();
      final transitions = <PassphraseWalletState>[];
      final subscription = cubit.stream.listen(transitions.add);
      addTearDown(subscription.cancel);

      wallets.publishCatalog([]);
      await pumpEventQueue();

      expect(transitions, hasLength(1));
      expect(transitions.single.hasLoadedWallet, isFalse);
    });

    test('a background lock emits exactly one state transition', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      await cubit.load();
      wallets.publishCatalog(['wallet-one']);
      await pumpEventQueue();
      final transitions = <PassphraseWalletState>[];
      final subscription = cubit.stream.listen(transitions.add);
      addTearDown(subscription.cancel);

      wallets.lockPrivateWalletSession();
      wallets.publishCatalog([]);
      await pumpEventQueue();

      expect(transitions, hasLength(1));
      expect(transitions.single.hasLoadedWallet, isFalse);
    });

    test(
      'a catalog change that does not move the loaded wallet is not a transition',
      () async {
        await givenLockedWallet(
          walletId: 'wallet-one',
          descriptor: firstDescriptor,
        );
        await cubit.load();
        wallets.publishCatalog(['wallet-one']);
        await pumpEventQueue();
        final transitions = <PassphraseWalletState>[];
        final subscription = cubit.stream.listen(transitions.add);
        addTearDown(subscription.cancel);

        // A second wallet appearing on Home says nothing about this page.
        wallets.publishCatalog(['wallet-one', 'some-other-wallet']);
        await pumpEventQueue();

        expect(transitions, isEmpty);
      },
    );

    test('a page load reads the loaded wallet from the wallet feature', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      wallets.loadedWalletId = 'wallet-one';

      await cubit.load();

      // The bug this replaces: the card said Locked while the wallet was loaded.
      expect(cubit.state.isLoaded('wallet-one'), isTrue);
      expect(cubit.state.hasLoadedWallet, isTrue);
    });
  });

  group('entry', () {
    test(
      'a known passphrase unlocks without asking for confirmation',
      () async {
        await givenLockedWallet(
          walletId: 'wallet-one',
          descriptor: firstDescriptor,
          label: 'Vault',
        );
        await cubit.load();
        cubit.startEntering();

        final result = await cubit.submitPassphrase('known');

        expect(
          result,
          isA<Ok<PassphraseWalletEntryResult, PassphraseWalletFailure>>()
              .having(
                (value) => value.value.status,
                'status',
                PassphraseWalletEntryStatus.openedKnown,
              ),
        );
        expect(wallets.events, ['mount:wallet-one:Vault']);
        expect(cubit.state.isEntering, isFalse);
        expect(cubit.state.isSubmitting, isFalse);
      },
    );

    test(
      'an unknown passphrase with history reports both warning stages',
      () async {
        await givenLockedWallet(
          walletId: 'wallet-one',
          descriptor: firstDescriptor,
        );
        await cubit.load();

        final result = await cubit.submitPassphrase('brand new');

        final entry =
            (result as Ok<PassphraseWalletEntryResult, PassphraseWalletFailure>)
                .value;
        // Stage one is the general disclaimer every new wallet gets; stage two is
        // the unmatched warning, which only history earns.
        expect(entry.status, PassphraseWalletEntryStatus.newWallet);
        expect(entry.hasHistory, isTrue);
        expect(cubit.state.isSubmitting, isTrue);
        expect(wallets.events, isEmpty);
      },
    );

    test(
      'the first ever wallet reports no history, so only stage one',
      () async {
        await cubit.load();

        final result = await cubit.submitPassphrase('brand new');

        final entry =
            (result as Ok<PassphraseWalletEntryResult, PassphraseWalletFailure>)
                .value;
        expect(entry.status, PassphraseWalletEntryStatus.newWallet);
        expect(entry.hasHistory, isFalse);
      },
    );

    test(
      'discarding the candidate clears its material and ends the attempt',
      () async {
        await cubit.load();
        cubit.startEntering();
        await cubit.submitPassphrase('brand new');

        cubit.discardCandidate();

        expect(deriver.issued['brand new']!.bytes, everyElement(0));
        expect(cubit.state.isSubmitting, isFalse);
        // Edit passphrase leaves the input open for another try.
        expect(cubit.state.isEntering, isTrue);
      },
    );

    test(
      'leaving the foreground clears the candidate and closes the input',
      () async {
        await cubit.load();
        cubit.startEntering();
        await cubit.submitPassphrase('brand new');

        cubit.cancelEntry();

        expect(deriver.issued['brand new']!.bytes, everyElement(0));
        expect(cubit.state.isEntering, isFalse);
        expect(cubit.state.isSubmitting, isFalse);
      },
    );

    test('cancelling while derivation is running drops its result', () async {
      final gate = Completer<void>();
      deriver.gate = gate;
      await cubit.load();
      cubit.startEntering();
      final submitted = cubit.submitPassphrase('brand new');
      await pumpEventQueue();

      cubit.cancelEntry();
      gate.complete();
      final result = await submitted;

      expect(result, isA<Err>());
      expect(deriver.issued['brand new']!.bytes, everyElement(0));
      expect(wallets.events, isEmpty);
      expect(cubit.state.isEntering, isFalse);
      expect(cubit.state.isSubmitting, isFalse);
    });

    test('cancelling a known-wallet mount prevents a late unlock', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      await cubit.load();
      final started = Completer<void>();
      final gate = Completer<void>();
      wallets.mountStarted = started;
      wallets.mountGate = gate;
      final submitted = cubit.submitPassphrase('known');
      await started.future;

      cubit.cancelEntry();
      expect(deriver.issued['known']!.bytes, everyElement(0));
      gate.complete();
      final result = await submitted;

      expect(result, isA<Err>());
      expect(deriver.issued['known']!.bytes, everyElement(0));
      expect(wallets.loadedWalletId, isNull);
    });

    test('a cancelled new-wallet mount stays saved but locked', () async {
      await cubit.load();
      await cubit.submitPassphrase('brand new');
      final started = Completer<void>();
      final gate = Completer<void>();
      wallets.mountStarted = started;
      wallets.mountGate = gate;
      final confirmed = cubit.confirmNewWallet();
      await started.future;

      cubit.cancelEntry();
      expect(deriver.issued['brand new']!.bytes, everyElement(0));
      gate.complete();
      final result = await confirmed;

      expect(
        result,
        isA<Ok<PassphraseWalletOpenStatus, PassphraseWalletFailure>>().having(
          (value) => value.value,
          'status',
          PassphraseWalletOpenStatus.savedButNotOpened,
        ),
      );
      expect(deriver.issued['brand new']!.bytes, everyElement(0));
      expect(wallets.loadedWalletId, isNull);
      final stored = await manifest.readManifest(
        Fingerprint(parentFingerprint),
      );
      expect(
        (stored as Ok<KeychainManifest, KeychainManifestFailure>).value.entries
            .expand((entry) => entry.materializations)
            .whereType<KeychainManifestWallet>(),
        hasLength(1),
      );
    });

    test('closing the page clears a candidate nobody confirmed', () async {
      await cubit.load();
      await cubit.submitPassphrase('brand new');

      await cubit.close();

      expect(deriver.issued['brand new']!.bytes, everyElement(0));
    });

    test('confirming creates the wallet and hands over the material', () async {
      await cubit.load();
      await cubit.submitPassphrase('brand new');

      final result = await cubit.confirmNewWallet(label: 'Savings');

      expect(
        result,
        isA<Ok<PassphraseWalletOpenStatus, PassphraseWalletFailure>>().having(
          (value) => value.value,
          'status',
          PassphraseWalletOpenStatus.opened,
        ),
      );
      expect(deriver.issued['brand new']!.bytes, everyElement(isNot(0)));
      expect(cubit.state.isEntering, isFalse);
      expect(cubit.state.isSubmitting, isFalse);
    });

    test(
      'a wallet saved but not opened leaves the input where it was',
      () async {
        wallets.mountError = Exception('storage is gone');
        await cubit.load();
        cubit.startEntering();
        await cubit.submitPassphrase('brand new');

        final result = await cubit.confirmNewWallet();

        expect(
          result,
          isA<Ok<PassphraseWalletOpenStatus, PassphraseWalletFailure>>().having(
            (value) => value.value,
            'status',
            PassphraseWalletOpenStatus.savedButNotOpened,
          ),
        );
        // The user's next move is to unlock it, from this same input.
        expect(cubit.state.isEntering, isTrue);
        expect(cubit.state.isSubmitting, isFalse);
      },
    );

    test('confirming twice cannot reuse a spent candidate', () async {
      await cubit.load();
      await cubit.submitPassphrase('brand new');
      await cubit.confirmNewWallet();

      expect(await cubit.confirmNewWallet(), isA<Err>());
    });

    test('no passphrase or candidate reaches the page state', () async {
      await cubit.load();
      await cubit.submitPassphrase('brand new');

      final dumped = [
        cubit.state.toString(),
        cubit.state.wallets.toString(),
        '${cubit.state.failure}',
      ].join(' ');
      expect(dumped, isNot(contains('brand new')));
      expect(dumped, isNot(contains('abandon')));
    });
  });

  group('locked balance scan', () {
    test('entering the page scans each locked descriptor once', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      await givenLockedWallet(
        walletId: 'wallet-two',
        descriptor: secondDescriptor,
        createdAt: 2,
      );

      await cubit.load();

      expect(scanner.scanned, [firstDescriptor, secondDescriptor]);
      final cards = {
        for (final card in cubit.state.wallets) card.wallet.walletId: card,
      };
      expect(
        cards['wallet-one']!.balanceStatus,
        PassphraseWalletBalanceStatus.success,
      );
      expect(cards['wallet-one']!.balance!.satoshis, BigInt.from(1500));
      expect(
        cards['wallet-two']!.balanceStatus,
        PassphraseWalletBalanceStatus.success,
      );
    });

    test('nothing scans until the page is entered', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );

      wallets.publishCatalog(['wallet-one']);
      await pumpEventQueue();

      expect(scanner.scanned, isEmpty);
    });

    test('results arriving after the page is left are ignored', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      final gate = Completer<void>();
      scanner.gate = gate;
      final loading = cubit.load();
      await pumpEventQueue();

      await cubit.close();
      gate.complete();
      await loading;

      expect(
        cubit.state.wallets.single.balanceStatus,
        PassphraseWalletBalanceStatus.syncing,
        reason: 'the late balance must not be written into a page nobody sees',
      );
    });

    test('one failed card can be retried on its own', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      await givenLockedWallet(
        walletId: 'wallet-two',
        descriptor: secondDescriptor,
        createdAt: 2,
      );
      scanner.failing.add(secondDescriptor);
      await cubit.load();
      expect(
        cubit.state.wallets.last.balanceStatus,
        PassphraseWalletBalanceStatus.failure,
      );
      scanner.failing.clear();
      scanner.scanned.clear();

      await cubit.retryBalance('wallet-two');

      expect(scanner.scanned, [secondDescriptor]);
      expect(
        cubit.state.wallets.last.balanceStatus,
        PassphraseWalletBalanceStatus.success,
      );
      expect(
        cubit.state.wallets.first.balanceStatus,
        PassphraseWalletBalanceStatus.success,
      );
    });
  });

  group('card actions', () {
    test('a hint edit updates the card from manifest truth', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
        hint: 'the old one',
      );
      await cubit.load();

      final updated = await cubit.updateHint(
        cubit.state.wallets.single.wallet,
        '  a better reminder  ',
      );

      expect(updated, isTrue);
      expect(cubit.state.wallets.single.wallet.hint, 'a better reminder');
      expect(cubit.state.failure, isNull);
    });

    test('forget removes the card', () async {
      await givenLockedWallet(
        walletId: 'wallet-one',
        descriptor: firstDescriptor,
      );
      await cubit.load();
      wallets.publishCatalog(['wallet-one']);
      await pumpEventQueue();

      final forgotten = await cubit.forget(cubit.state.wallets.single.wallet);

      expect(forgotten, isTrue);
      expect(cubit.state.wallets, isEmpty);
      expect(cubit.state.hasLoadedWallet, isFalse);
    });

    test(
      'a half-finished forget keeps the card so the user can retry',
      () async {
        await givenLockedWallet(
          walletId: 'wallet-one',
          descriptor: firstDescriptor,
        );
        await cubit.load();
        manifestRepository.failRemove = true;

        final forgotten = await cubit.forget(cubit.state.wallets.single.wallet);

        expect(forgotten, isFalse);
        expect(cubit.state.wallets.single.wallet.walletId, 'wallet-one');
        expect(cubit.state.failure, isNotNull);

        manifestRepository.failRemove = false;
        expect(await cubit.forget(cubit.state.wallets.single.wallet), isTrue);
        expect(cubit.state.wallets, isEmpty);
      },
    );
  });
}
