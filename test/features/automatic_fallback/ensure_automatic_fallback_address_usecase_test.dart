import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/ensure_automatic_fallback_address_usecase.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Settings extends Mock implements GetSettingsUsecase {}

class _Wallets extends Mock implements WalletRepository {}

class _Addresses extends Mock implements WalletAddressRepository {}

class _Bitcoin extends Mock implements BitcoinWalletRepository {}

class _Labels extends Mock implements LabelsFacade {}

void main() {
  late _Settings settings;
  late _Wallets wallets;
  late _Addresses addresses;
  late _Bitcoin bitcoin;
  late _Labels labels;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.addr(address: 'bc1address', label: 'Automatic Fallback'),
    );
  });

  setUp(() {
    settings = _Settings();
    wallets = _Wallets();
    addresses = _Addresses();
    bitcoin = _Bitcoin();
    labels = _Labels();
    when(() => settings.execute()).thenAnswer((_) async => _settings);
    when(() => labels.fetchAll()).thenAnswer((_) async => []);
    when(() => labels.store(any())).thenAnswer(
      (_) async => Ok(
        Label.addr(id: 1, address: 'bc1address', label: 'Automatic Fallback'),
      ),
    );
  });

  void stubDefaultWallet() {
    when(
      () =>
          wallets.getDefaultBitcoinWalletIds(environment: Environment.mainnet),
    ).thenAnswer((_) async => ['wallet']);
  }

  EnsureAutomaticFallbackAddressUsecase usecase({
    required List<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
    remoteReads,
    Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
    Function(String address)?
    registerRemote,
  }) {
    final reads = List.of(remoteReads);
    return EnsureAutomaticFallbackAddressUsecase(
      settings,
      wallets,
      addresses,
      bitcoin,
      labels,
      () async => reads.removeAt(0),
      registerRemote ?? (_) async => const Ok(_registered),
    );
  }

  test('requires exactly one default Bitcoin wallet', () async {
    for (final ids in <List<String>>[
      [],
      ['one', 'two'],
    ]) {
      when(
        () => wallets.getDefaultBitcoinWalletIds(
          environment: Environment.mainnet,
        ),
      ).thenAnswer((_) async => ids);
      final sut = usecase(remoteReads: [const Ok(_absent)]);

      final result = await sut.execute();

      final failure = (result as Err).failure as AutomaticFallbackFailure;
      expect(
        failure.kind,
        ids.isEmpty
            ? AutomaticFallbackFailureKind.noDefaultBitcoinWallet
            : AutomaticFallbackFailureKind.ambiguousDefaultBitcoinWallet,
      );
    }
  });

  test(
    'verifies and labels an existing remote address without writing',
    () async {
      stubDefaultWallet();
      when(
        () => bitcoin.isAddressOfWallet('bc1existing', walletId: 'wallet'),
      ).thenAnswer((_) async => true);
      var remoteWrites = 0;
      final sut = usecase(
        remoteReads: [const Ok(_existing)],
        registerRemote: (_) async {
          remoteWrites++;
          return const Ok(_registered);
        },
      );

      final result = await sut.execute();

      final setup = (result as Ok).value;
      expect(setup.btcAddress, 'bc1existing');
      expect(setup.registeredNow, isFalse);
      expect(remoteWrites, 0);
      verify(() => labels.store(any())).called(1);
    },
  );

  test(
    'registers a newly generated owned address and verifies readback',
    () async {
      stubDefaultWallet();
      when(
        () => addresses.generateNewReceiveAddress(walletId: 'wallet'),
      ).thenAnswer((_) async => _address('bc1new'));
      when(
        () => bitcoin.isAddressOfWallet('bc1new', walletId: 'wallet'),
      ).thenAnswer((_) async => true);
      String? submitted;
      final sut = usecase(
        remoteReads: [const Ok(_absent), const Ok(_newReadback)],
        registerRemote: (address) async {
          submitted = address;
          return const Ok(_registered);
        },
      );

      final result = await sut.execute();

      expect(submitted, 'bc1new');
      expect((result as Ok).value.registeredNow, isTrue);
    },
  );

  test('reuses a locally reserved address after an uncertain write', () async {
    stubDefaultWallet();
    when(() => labels.fetchAll()).thenAnswer(
      (_) async => [
        Label.addr(
          id: 1,
          address: 'bc1pending',
          label: LabelSystem.automaticFallback.label,
          origin: '${automaticFallbackAddressOriginPrefix}wallet',
        ),
      ],
    );
    when(
      () => bitcoin.isAddressOfWallet('bc1pending', walletId: 'wallet'),
    ).thenAnswer((_) async => true);
    final sut = usecase(
      remoteReads: [const Ok(_absent), const Ok(_pendingReadback)],
    );

    final result = await sut.execute();

    expect((result as Ok).value.btcAddress, 'bc1pending');
    verifyNever(
      () =>
          addresses.generateNewReceiveAddress(walletId: any(named: 'walletId')),
    );
  });

  test('rejects a remote address not owned by the default wallet', () async {
    stubDefaultWallet();
    when(
      () => bitcoin.isAddressOfWallet('bc1existing', walletId: 'wallet'),
    ).thenAnswer((_) async => false);

    final result = await usecase(remoteReads: [const Ok(_existing)]).execute();

    expect(
      (result as Err).failure,
      isA<AutomaticFallbackFailure>().having(
        (failure) => failure.kind,
        'kind',
        AutomaticFallbackFailureKind.addressNotOwned,
      ),
    );
  });

  test('rejects a mismatched authoritative readback', () async {
    stubDefaultWallet();
    when(
      () => addresses.generateNewReceiveAddress(walletId: 'wallet'),
    ).thenAnswer((_) async => _address('bc1new'));
    when(
      () => bitcoin.isAddressOfWallet('bc1new', walletId: 'wallet'),
    ).thenAnswer((_) async => true);

    final result = await usecase(
      remoteReads: [const Ok(_absent), const Ok(_existing)],
    ).execute();

    expect(
      (result as Err).failure,
      isA<AutomaticFallbackFailure>().having(
        (failure) => failure.kind,
        'kind',
        AutomaticFallbackFailureKind.integrityMismatch,
      ),
    );
  });

  test(
    'maps an unavailable signer without leaking the foreign failure',
    () async {
      stubDefaultWallet();
      final result = await usecase(
        remoteReads: const [Err(BullnymAuthenticationFailure('locked'))],
      ).execute();

      expect(
        (result as Err).failure,
        isA<AutomaticFallbackFailure>().having(
          (failure) => failure.kind,
          'kind',
          AutomaticFallbackFailureKind.signingUnavailable,
        ),
      );
    },
  );
}

const _settings = SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
);
const _absent = BullnymRecoveryAddressLookupResult(
  version: 1,
  isRegistered: false,
);
const _existing = BullnymRecoveryAddressLookupResult(
  version: 1,
  isRegistered: true,
  btcAddress: 'bc1existing',
  commitmentVersion: 1,
  signedAtUnix: 1,
);
const _newReadback = BullnymRecoveryAddressLookupResult(
  version: 1,
  isRegistered: true,
  btcAddress: 'bc1new',
  commitmentVersion: 1,
  signedAtUnix: 1,
);
const _pendingReadback = BullnymRecoveryAddressLookupResult(
  version: 1,
  isRegistered: true,
  btcAddress: 'bc1pending',
  commitmentVersion: 1,
  signedAtUnix: 1,
);
const _registered = BullnymRecoveryAddressRegistrationResult(
  version: 1,
  isRegistered: true,
  signedAtUnix: 1,
);

WalletAddress _address(String address) => WalletAddress(
  walletId: 'wallet',
  index: 0,
  address: address,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
