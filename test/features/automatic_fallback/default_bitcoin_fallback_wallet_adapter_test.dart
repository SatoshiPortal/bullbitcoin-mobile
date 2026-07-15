import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/automatic_fallback/data/default_bitcoin_fallback_wallet_adapter.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_wallet_port.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetWallets extends Mock implements GetWalletsUsecase {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockNostrIdentity extends Mock implements NostrIdentityFacade {}

class _MockWalletAddressRepository extends Mock
    implements WalletAddressRepository {}

class _MockBitcoinWalletRepository extends Mock
    implements BitcoinWalletRepository {}

class _MockLabelsFacade extends Mock implements LabelsFacade {}

class _MockWallet extends Mock implements Wallet {}

AutomaticFallbackFailure _failure<T>(
  Result<T, AutomaticFallbackFailure> result,
) {
  expect(result, isA<Err<T, AutomaticFallbackFailure>>());
  return (result as Err<T, AutomaticFallbackFailure>).failure;
}

void main() {
  const fingerprint = 'a1b2c3d4';
  const walletId = 'default-bitcoin';
  final seedBytes = Uint8List.fromList(
    List<int>.generate(64, (index) => index + 1),
  );

  late _MockGetWallets getWallets;
  late _MockSeedRepository seeds;
  late _MockNostrIdentity nostrIdentity;
  late _MockWalletAddressRepository addresses;
  late _MockBitcoinWalletRepository bitcoinWallet;
  late _MockLabelsFacade labels;
  late _MockWallet wallet;
  late DefaultBitcoinFallbackWalletAdapter adapter;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.addr(address: 'fallback', label: 'fallback'),
    );
  });

  setUp(() {
    getWallets = _MockGetWallets();
    seeds = _MockSeedRepository();
    nostrIdentity = _MockNostrIdentity();
    addresses = _MockWalletAddressRepository();
    bitcoinWallet = _MockBitcoinWalletRepository();
    labels = _MockLabelsFacade();
    wallet = _MockWallet();

    when(() => wallet.id).thenReturn(walletId);
    when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
    when(() => wallet.signsLocally).thenReturn(true);
    when(() => wallet.masterFingerprint).thenReturn(fingerprint);
    when(
      () => getWallets.execute(onlyDefaults: true, onlyBitcoin: true),
    ).thenAnswer((_) async => [wallet]);
    when(() => seeds.get(fingerprint)).thenAnswer(
      (_) async => Seed.bytes(bytes: seedBytes, masterFingerprint: fingerprint),
    );
    when(
      () => nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(any()),
    ).thenReturn('fixture-npub');
    when(
      () => nostrIdentity.signBullnymServerAuthHashFromXprv(
        xprvBase58: any(named: 'xprvBase58'),
        messageHashHex: any(named: 'messageHashHex'),
      ),
    ).thenReturn('fixture-signature');

    adapter = DefaultBitcoinFallbackWalletAdapter(
      getWallets: getWallets,
      seeds: seeds,
      nostrIdentity: nostrIdentity,
      addresses: addresses,
      bitcoinWallet: bitcoinWallet,
      labels: labels,
    );
  });

  test(
    'derives an ephemeral Bullnym signer from the one default wallet',
    () async {
      final result = await adapter.loadCurrentDefaultBitcoinWallet();

      final context =
          (result
                  as Ok<
                    AutomaticFallbackWalletContext,
                    AutomaticFallbackFailure
                  >)
              .value;
      expect(context.walletId, walletId);
      expect(context.signer.npubHex, 'fixture-npub');
      expect(
        await context.signer.signHashHex('fixture-hash'),
        'fixture-signature',
      );
      final derivedXprv =
          verify(
                () => nostrIdentity.deriveBullnymServerAuthPublicKeyFromXprv(
                  captureAny(),
                ),
              ).captured.single
              as String;
      expect(derivedXprv, startsWith('xprv'));
      verify(
        () => nostrIdentity.signBullnymServerAuthHashFromXprv(
          xprvBase58: derivedXprv,
          messageHashHex: 'fixture-hash',
        ),
      ).called(1);
    },
  );

  test('rejects non-mainnet wallets before reading seed material', () async {
    when(() => wallet.network).thenReturn(Network.bitcoinTestnet);

    final result = await adapter.loadCurrentDefaultBitcoinWallet();

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.unsupportedNetwork,
    );
    verifyNever(() => seeds.get(any()));
  });

  test('rejects a wallet that cannot sign locally', () async {
    when(() => wallet.signsLocally).thenReturn(false);

    final result = await adapter.loadCurrentDefaultBitcoinWallet();

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.signingUnavailable,
    );
    verifyNever(() => seeds.get(any()));
  });

  test('rejects an ambiguous default Bitcoin wallet set', () async {
    when(
      () => getWallets.execute(onlyDefaults: true, onlyBitcoin: true),
    ).thenAnswer((_) async => [wallet, wallet]);

    final result = await adapter.loadCurrentDefaultBitcoinWallet();

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.ambiguousDefaultBitcoinWallet,
    );
    verifyNever(() => seeds.get(any()));
  });

  test(
    'maps wallet lookup exceptions separately from signing failures',
    () async {
      when(
        () => getWallets.execute(onlyDefaults: true, onlyBitcoin: true),
      ).thenThrow(Exception('settings unavailable'));

      final result = await adapter.loadCurrentDefaultBitcoinWallet();

      expect(
        _failure(result).kind,
        AutomaticFallbackFailureKind.walletLookupFailed,
      );
      verifyNever(() => seeds.get(any()));
    },
  );

  test('maps a missing default wallet to its retryable failure', () async {
    when(
      () => getWallets.execute(onlyDefaults: true, onlyBitcoin: true),
    ).thenThrow(NoWalletsFoundException('none'));

    final result = await adapter.loadCurrentDefaultBitcoinWallet();

    final failure = _failure(result);
    expect(failure.kind, AutomaticFallbackFailureKind.noDefaultBitcoinWallet);
    expect(failure.retryable, isTrue);
    verifyNever(() => seeds.get(any()));
  });

  test(
    'finds only an owned reservation with the exact wallet origin',
    () async {
      final context = AutomaticFallbackWalletContext(
        walletId: walletId,
        signer: BullnymAuthSigner(
          npubHex: 'fixture-npub',
          signHashHex: (_) => 'fixture-signature',
        ),
      );
      when(() => labels.fetchAll()).thenAnswer(
        (_) async => [
          Label.addr(
            id: 1,
            address: 'owned',
            label: LabelSystem.automaticFallback.label,
            origin: '$automaticFallbackAddressOriginPrefix$walletId',
          ),
          Label.addr(
            id: 2,
            address: 'wrong-origin',
            label: LabelSystem.automaticFallback.label,
            origin: '${automaticFallbackAddressOriginPrefix}another-wallet',
          ),
          Label.addr(
            id: 3,
            address: 'user-label',
            label: 'user label',
            origin: '$automaticFallbackAddressOriginPrefix$walletId',
          ),
        ],
      );
      when(
        () => bitcoinWallet.isAddressOfWallet('owned', walletId: walletId),
      ).thenAnswer((_) async => true);

      final result = await adapter.findPendingAddress(context);

      expect((result as Ok<String?, AutomaticFallbackFailure>).value, 'owned');
      verify(
        () => bitcoinWallet.isAddressOfWallet('owned', walletId: walletId),
      ).called(1);
      verifyNoMoreInteractions(bitcoinWallet);
    },
  );

  test('multiple owned reservations fail closed', () async {
    final context = AutomaticFallbackWalletContext(
      walletId: walletId,
      signer: BullnymAuthSigner(
        npubHex: 'fixture-npub',
        signHashHex: (_) => 'fixture-signature',
      ),
    );
    when(() => labels.fetchAll()).thenAnswer(
      (_) async => [
        Label.addr(
          id: 1,
          address: 'first',
          label: LabelSystem.automaticFallback.label,
          origin: '$automaticFallbackAddressOriginPrefix$walletId',
        ),
        Label.addr(
          id: 2,
          address: 'second',
          label: LabelSystem.automaticFallback.label,
          origin: '$automaticFallbackAddressOriginPrefix$walletId',
        ),
      ],
    );
    when(
      () => bitcoinWallet.isAddressOfWallet(any(), walletId: walletId),
    ).thenAnswer((_) async => true);

    final result = await adapter.findPendingAddress(context);

    expect(
      _failure(result).kind,
      AutomaticFallbackFailureKind.conflictingLocalReservations,
    );
  });

  test('stores the exact system label and wallet-scoped origin', () async {
    final context = AutomaticFallbackWalletContext(
      walletId: walletId,
      signer: BullnymAuthSigner(
        npubHex: 'fixture-npub',
        signHashHex: (_) => 'fixture-signature',
      ),
    );
    when(() => labels.store(any())).thenAnswer((invocation) async {
      final newLabel = invocation.positionalArguments.single as NewLabel;
      return Ok(
        Label.addr(
          id: 1,
          address: newLabel.reference,
          label: newLabel.label,
          origin: newLabel.origin,
        ),
      );
    });

    final result = await adapter.ensureLabel(context, 'bc1qfallback');

    expect(result, isA<Ok<void, AutomaticFallbackFailure>>());
    final stored =
        verify(() => labels.store(captureAny())).captured.single as NewLabel;
    expect(stored.type, LabelType.address);
    expect(stored.label, LabelSystem.automaticFallback.label);
    expect(stored.reference, 'bc1qfallback');
    expect(stored.origin, '$automaticFallbackAddressOriginPrefix$walletId');
  });

  test(
    'fresh address selection delegates to the external receive path',
    () async {
      final context = AutomaticFallbackWalletContext(
        walletId: walletId,
        signer: BullnymAuthSigner(
          npubHex: 'fixture-npub',
          signHashHex: (_) => 'fixture-signature',
        ),
      );
      when(
        () => addresses.generateNewReceiveAddress(walletId: walletId),
      ).thenAnswer(
        (_) async => WalletAddress(
          walletId: walletId,
          index: 7,
          address: 'bc1qfresh',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

      final result = await adapter.generateFreshAddress(context);

      expect(
        (result as Ok<String, AutomaticFallbackFailure>).value,
        'bc1qfresh',
      );
      verify(
        () => addresses.generateNewReceiveAddress(walletId: walletId),
      ).called(1);
    },
  );
}
