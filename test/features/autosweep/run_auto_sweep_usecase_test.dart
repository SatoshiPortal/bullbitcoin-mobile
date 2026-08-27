import 'dart:async';

import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_liquid_transaction_usecase.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/liquid_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_failure.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_fee_policy.dart';
import 'package:bb_mobile/features/autosweep/domain/autosweep_result.dart';
import 'package:bb_mobile/features/autosweep/domain/usecases/run_auto_sweep_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _WalletRepository extends Mock implements WalletRepository {}

class _AddressRepository extends Mock implements WalletAddressRepository {}

class _LiquidRepository extends Mock implements LiquidWalletRepository {}

class _BitcoinRepository extends Mock implements BitcoinWalletRepository {}

class _BroadcastLiquid extends Mock
    implements BroadcastLiquidTransactionUsecase {}

class _BroadcastBitcoin extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _GetFees extends Mock implements GetNetworkFeesUsecase {}

class _Labels extends Mock implements LabelsFacade {}

void main() {
  late _WalletRepository wallets;
  late _AddressRepository addresses;
  late _LiquidRepository liquid;
  late _BitcoinRepository bitcoin;
  late _BroadcastLiquid broadcastLiquid;
  late _BroadcastBitcoin broadcastBitcoin;
  late _GetFees fees;
  late _Labels labels;

  setUpAll(() {
    registerFallbackValue(
      NewLabel.tx(transactionId: 'tx', label: 'label', origin: 'wallet'),
    );
    registerFallbackValue(NetworkFee.relativeFromSatPerVbyte(1));
  });

  setUp(() {
    wallets = _WalletRepository();
    addresses = _AddressRepository();
    liquid = _LiquidRepository();
    bitcoin = _BitcoinRepository();
    broadcastLiquid = _BroadcastLiquid();
    broadcastBitcoin = _BroadcastBitcoin();
    fees = _GetFees();
    labels = _Labels();
    when(() => labels.store(any())).thenAnswer((_) async => Ok(_label));
  });

  RunAutoSweepUsecase usecase({
    required Wallet source,
    bool enabled = true,
    AutosweepFeePolicy feePolicy = const AutosweepFeePolicy(),
  }) => RunAutoSweepUsecase(
    wallets,
    addresses,
    liquid,
    bitcoin,
    broadcastLiquid,
    broadcastBitcoin,
    fees,
    labels,
    feePolicy,
    () async => Ok([
      WalletPreferences(walletRef: source.id, autoSweepEnabled: enabled),
    ]),
  );

  void stubDefaultWallet(Wallet wallet) {
    when(
      () => wallets.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: true,
        onlyBitcoin: !wallet.isLiquid,
        onlyLiquid: wallet.isLiquid,
      ),
    ).thenAnswer((_) async => [wallet]);
  }

  test('fails closed when autosweep is disabled', () async {
    final source = _wallet(id: 'source', liquid: true);

    final result = await usecase(
      source: source,
      enabled: false,
    ).execute(source);

    expect(result, isA<AutosweepSkipped>());
    expect((result as AutosweepSkipped).reason, AutosweepSkipReason.disabled);
    verifyNever(
      () => wallets.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
      ),
    );
  });

  test(
    'drains Liquid to the default Liquid wallet and labels the tx',
    () async {
      final source = _wallet(
        id: 'source',
        liquid: true,
        label: 'Lightning Address Liquid',
      );
      final destination = _wallet(id: 'default', liquid: true, isDefault: true);
      stubDefaultWallet(destination);
      when(
        () => addresses.getLastRevealedReceiveAddress(walletId: 'default'),
      ).thenAnswer((_) async => _address('default', 'lq1destination'));
      when(
        () => liquid.buildPset(
          walletId: 'source',
          address: 'lq1destination',
          feeRate: any(named: 'feeRate'),
          drain: true,
        ),
      ).thenAnswer((_) async => 'pset');
      when(
        () => liquid.signPset(pset: 'pset', walletId: 'source'),
      ).thenAnswer((_) async => 'signed');
      when(
        () => broadcastLiquid.execute('signed', isTestnet: false),
      ).thenAnswer((_) async => 'txid');

      final result = await usecase(source: source).execute(source);

      expect(result, isA<AutosweepSwept>());
      expect((result as AutosweepSwept).txid, 'txid');
      verify(() => labels.store(any())).called(1);
    },
  );

  test('skips Bitcoin when the drain fee exceeds policy', () async {
    final source = _wallet(id: 'source', liquid: false, balance: 10_000);
    final destination = _wallet(id: 'default', liquid: false, isDefault: true);
    stubDefaultWallet(destination);
    when(
      () => addresses.getLastRevealedReceiveAddress(walletId: 'default'),
    ).thenAnswer((_) async => _address('default', 'bc1destination'));
    when(() => fees.execute(isLiquid: false)).thenAnswer(
      (_) async => FeeOptions(
        fastest: NetworkFee.relativeFromSatPerVbyte(10),
        minRelay: NetworkFee.relativeFromSatPerVbyte(0.1),
        economic: NetworkFee.relativeFromSatPerVbyte(1),
        slow: NetworkFee.relativeFromSatPerVbyte(1),
      ),
    );
    when(
      () => bitcoin.buildPsbt(
        walletId: 'source',
        address: 'bc1destination',
        networkFee: any(named: 'networkFee'),
        drain: true,
      ),
    ).thenAnswer((_) async => 'psbt');
    when(
      () => bitcoin.getTxFeeAmount(psbt: 'psbt'),
    ).thenAnswer((_) async => 500);

    final result = await usecase(source: source).execute(source);

    expect((result as AutosweepSkipped).reason, AutosweepSkipReason.feePolicy);
    verifyNever(
      () => bitcoin.signPsbt(any(), walletId: any(named: 'walletId')),
    );
  });

  test('deduplicates concurrent sweeps for the same wallet', () async {
    final source = _wallet(id: 'source', liquid: true);
    final destination = _wallet(id: 'default', liquid: true, isDefault: true);
    final pending = Completer<WalletAddress>();
    stubDefaultWallet(destination);
    when(
      () => addresses.getLastRevealedReceiveAddress(walletId: 'default'),
    ).thenAnswer((_) => pending.future);
    final sut = usecase(source: source);

    final first = sut.execute(source);
    await Future<void>.delayed(Duration.zero);
    final second = await sut.execute(source);
    pending.complete(_address('default', 'lq1destination'));
    when(
      () => liquid.buildPset(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        feeRate: any(named: 'feeRate'),
        drain: true,
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => liquid.signPset(pset: 'pset', walletId: 'source'),
    ).thenAnswer((_) async => 'signed');
    when(
      () => broadcastLiquid.execute('signed', isTestnet: false),
    ).thenAnswer((_) async => 'txid');

    expect((second as AutosweepSkipped).reason, AutosweepSkipReason.inFlight);
    expect(await first, isA<AutosweepSwept>());
  });

  test(
    'maps recoverable exceptions but lets programmer errors escape',
    () async {
      final source = _wallet(id: 'source', liquid: true);
      when(
        () => wallets.getWallets(
          environment: any(named: 'environment'),
          onlyDefaults: true,
          onlyBitcoin: false,
          onlyLiquid: true,
        ),
      ).thenThrow(Exception('offline'));
      final failed = await usecase(source: source).execute(source);
      expect(
        (failed as AutosweepFailed).failure,
        isA<AutosweepOperationFailure>(),
      );

      when(
        () => wallets.getWallets(
          environment: any(named: 'environment'),
          onlyDefaults: true,
          onlyBitcoin: false,
          onlyLiquid: true,
        ),
      ).thenThrow(StateError('programmer bug'));
      expect(() => usecase(source: source).execute(source), throwsStateError);
    },
  );
}

final _label = Label.tx(
  id: 1,
  transactionId: 'txid',
  label: 'Lightning Address',
  origin: 'source',
);

Wallet _wallet({
  required String id,
  required bool liquid,
  bool isDefault = false,
  int balance = 50_000,
  String? label,
}) => Wallet(
  origin: id,
  label: label,
  network: liquid ? Network.liquidMainnet : Network.bitcoinMainnet,
  isDefault: isDefault,
  xpubFingerprint: '12345678',
  scriptType: ScriptType.bip84,
  xpub: 'xpub',
  externalPublicDescriptor: 'external',
  internalPublicDescriptor: 'internal',
  signer: SignerEntity.local,
  signerDevice: null,
  balanceSat: BigInt.from(balance),
);

WalletAddress _address(String walletId, String address) => WalletAddress(
  walletId: walletId,
  index: 0,
  address: address,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
