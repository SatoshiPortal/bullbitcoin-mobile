import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/data/datasources/lwk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLwkWallet extends Mock implements lwk.Wallet {}

void main() {
  const wallet = WalletModel.publicLwk(
    id: 'liquid-wallet',
    combinedCtDescriptor: 'descriptor',
    isTestnet: true,
  );
  const selection = {(txId: 'selected', vout: 1)};
  const fee = RelativeFee(25);
  late _MockLwkWallet lwkWallet;
  late LwkWalletDatasource datasource;

  lwk.TxOut coin(
    String txid, {
    String asset = AssetConstants.lbtcTestnet,
    int? height = 100,
  }) => lwk.TxOut(
    scriptPubkey: 'script',
    outpoint: lwk.OutPoint(txid: txid, vout: 0),
    height: height,
    unblinded: lwk.TxOutSecrets(
      value: BigInt.from(20000),
      valueBf: '',
      asset: asset,
      assetBf: '',
    ),
    isSpent: false,
    address: const lwk.Address(
      standard: 'tex1address',
      confidential: 'tlq1address',
    ),
  );

  setUpAll(() => registerFallbackValue(BigInt.zero));

  setUp(() {
    lwkWallet = _MockLwkWallet();
    datasource = LwkWalletDatasource(
      createPublicWallet: (_) async => lwkWallet,
    );
    when(
      () => lwkWallet.buildCustomTx(
        utxos: any(named: 'utxos'),
        outputs: any(named: 'outputs'),
        drainTo: any(named: 'drainTo'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(
      () => lwkWallet.buildLbtcTx(
        sats: any(named: 'sats'),
        outAddress: any(named: 'outAddress'),
        feeRate: any(named: 'feeRate'),
        drain: any(named: 'drain'),
      ),
    ).thenAnswer((_) async => 'pset');
    when(() => lwkWallet.decodeTx(pset: 'pset')).thenAnswer(
      (_) async => lwk.PsetAmounts(absoluteFees: BigInt.from(50), balances: []),
    );
  });

  test('builds a fixed output using only the specified inputs', () async {
    await datasource.buildPset(
      wallet: wallet,
      address: 'recipient',
      amountSat: 20000,
      feeRate: fee,
      selectedInputs: selection,
    );

    verify(
      () => lwkWallet.buildCustomTx(
        utxos: [const lwk.OutPoint(txid: 'selected', vout: 1)],
        outputs: [
          lwk.TxOutputSpec(address: 'recipient', satoshi: BigInt.from(20000)),
        ],
        feeRate: 100,
      ),
    ).called(1);
    verifyNever(
      () => lwkWallet.buildLbtcTx(
        sats: any(named: 'sats'),
        outAddress: any(named: 'outAddress'),
        feeRate: any(named: 'feeRate'),
        drain: any(named: 'drain'),
      ),
    );
  });

  test(
    'drains selected coins to the recipient without a fixed output',
    () async {
      await datasource.buildPset(
        wallet: wallet,
        address: 'recipient',
        drain: true,
        feeRate: fee,
        selectedInputs: selection,
      );

      verify(
        () => lwkWallet.buildCustomTx(
          utxos: [const lwk.OutPoint(txid: 'selected', vout: 1)],
          outputs: [],
          drainTo: 'recipient',
          feeRate: 100,
        ),
      ).called(1);
    },
  );

  test('preserves automatic selection when no inputs are specified', () async {
    await datasource.buildPset(
      wallet: wallet,
      address: 'recipient',
      amountSat: 20000,
      feeRate: fee,
    );

    verify(
      () => lwkWallet.buildLbtcTx(
        sats: BigInt.from(20000),
        outAddress: 'recipient',
        feeRate: 100,
        drain: false,
      ),
    ).called(1);
  });

  test(
    'reports insufficient selected funds without retrying automatic selection',
    () async {
      when(
        () => lwkWallet.buildCustomTx(
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainTo: any(named: 'drainTo'),
          feeRate: any(named: 'feeRate'),
        ),
      ).thenThrow(const lwk.LwkError(msg: 'InsufficientFunds'));

      await expectLater(
        datasource.buildPset(
          wallet: wallet,
          address: 'recipient',
          amountSat: 20000,
          feeRate: fee,
          selectedInputs: selection,
        ),
        throwsA(isA<InsufficientFundsException>()),
      );
      verifyNever(
        () => lwkWallet.buildLbtcTx(
          sats: any(named: 'sats'),
          outAddress: any(named: 'outAddress'),
          feeRate: any(named: 'feeRate'),
          drain: any(named: 'drain'),
        ),
      );
    },
  );

  test('lists only L-BTC coins for the wallet network', () async {
    when(() => lwkWallet.utxos()).thenAnswer(
      (_) async => [coin('lbtc'), coin('other-asset', asset: 'other')],
    );

    final coins = await datasource.getUtxos(wallet: wallet);

    expect(coins.map((coin) => coin.txId), ['lbtc']);
    expect((coins.single as LiquidWalletUtxoModel).blockHeight, 100);
  });

  test(
    'consolidates only confirmed unfrozen L-BTC coins in bounded batches',
    () async {
      when(() => lwkWallet.utxos()).thenAnswer(
        (_) async => [
          for (final id in ['first', 'second', 'third', 'frozen']) coin(id),
          coin('pending', height: null),
          coin('other-asset', asset: 'other'),
        ],
      );
      when(() => lwkWallet.addressLastUnused()).thenAnswer(
        (_) async =>
            const lwk.Address(standard: '', confidential: '', index: 4),
      );
      when(() => lwkWallet.address(index: any(named: 'index'))).thenAnswer(
        (invocation) async => lwk.Address(
          standard: '',
          confidential: 'recipient-${invocation.namedArguments[#index]}',
        ),
      );

      final psets = await datasource.consolidate(
        wallet: wallet,
        feeRate: fee,
        highUtxoThreshold: 0,
        maximumInputs: 2,
        unspendable: {(txId: 'frozen', vout: 0)},
      );

      expect(psets, hasLength(2));
      final calls = verify(
        () => lwkWallet.buildCustomTx(
          utxos: captureAny(named: 'utxos'),
          outputs: [],
          drainTo: captureAny(named: 'drainTo'),
          feeRate: 100,
        ),
      ).captured;
      expect(calls, [
        [
          const lwk.OutPoint(txid: 'first', vout: 0),
          const lwk.OutPoint(txid: 'second', vout: 0),
        ],
        'recipient-4',
        [const lwk.OutPoint(txid: 'third', vout: 0)],
        'recipient-5',
      ]);
    },
  );
}
