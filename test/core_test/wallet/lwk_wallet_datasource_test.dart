import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
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
    network: Network.liquidTestnet,
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
    datasource = LwkWalletDatasource(readWallet: (_) async => lwkWallet);
    when(() => lwkWallet.policyAsset())
        .thenAnswer((_) async => AssetConstants.lbtcTestnet);
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

  test('preserves an unclassified typed LWK build exception', () async {
    const error = lwk.LwkError(msg: 'unclassified');
    when(() => lwkWallet.utxos()).thenAnswer((_) async => []);
    when(
      () => lwkWallet.buildCustomTx(
        utxos: any(named: 'utxos'),
        outputs: any(named: 'outputs'),
        drainTo: any(named: 'drainTo'),
        feeRate: any(named: 'feeRate'),
      ),
    ).thenThrow(error);
    await expectLater(
      datasource.buildPset(
        wallet: wallet,
        address: 'recipient',
        amountSat: 1000,
        feeRate: fee,
        selectedInputs: selection,
      ),
      throwsA(same(error)),
    );
  });

  test('rejects a missing fixed amount before invoking the SDK', () async {
    await expectLater(
      datasource.buildPset(
        wallet: wallet,
        address: 'recipient',
        feeRate: fee,
        selectedInputs: selection,
      ),
      throwsA(isA<Exception>()),
    );
    verifyZeroInteractions(lwkWallet);
  });

  test(
    'rejects a missing consolidation address index before building',
    () async {
      when(() => lwkWallet.utxos())
          .thenAnswer((_) async => [coin('first'), coin('second')]);
      when(() => lwkWallet.addressLastUnused()).thenAnswer(
        (_) async => const lwk.Address(standard: '', confidential: ''),
      );
      await expectLater(
        datasource.consolidate(
          wallet: wallet,
          feeRate: fee,
          highUtxoThreshold: 0,
          maximumInputs: 2,
          unspendable: {(txId: 'frozen', vout: 0)},
        ),
        throwsA(isA<Exception>()),
      );
      verifyNever(
        () => lwkWallet.buildCustomTx(
          utxos: any(named: 'utxos'),
          outputs: any(named: 'outputs'),
          drainTo: any(named: 'drainTo'),
          feeRate: any(named: 'feeRate'),
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

  group('Liquid self-transfer amount', () {
    lwk.TxOut owned(
      String confidential,
      int sats, {
      int vout = 0,
      String asset = AssetConstants.lbtcTestnet,
    }) => lwk.TxOut(
      scriptPubkey: 'script',
      outpoint: lwk.OutPoint(txid: 'self', vout: vout),
      unblinded: lwk.TxOutSecrets(
        value: BigInt.from(sats),
        valueBf: '',
        asset: asset,
        assetBf: '',
      ),
      isSpent: false,
      address: lwk.Address(standard: '', confidential: confidential),
    );

    lwk.Tx walletTx(
      List<lwk.TxOut> outputs, {
      String kind = 'redeposit',
      int balance = -33,
    }) => lwk.Tx(
      kind: kind,
      balances: [
        lwk.Balance(assetId: AssetConstants.lbtcTestnet, value: balance),
      ],
      txid: 'self',
      outputs: outputs,
      inputs: [owned('tlq1spent', 8527)],
      fee: BigInt.from(33),
      unblindedUrl: '',
      vsize: BigInt.from(1000),
    );

    Future<int> amountOf(lwk.Tx tx) async {
      when(() => lwkWallet.txs()).thenAnswer((_) async => [tx]);
      final txs = await datasource.getTransactions(wallet: wallet);
      return txs.single.amountSat;
    }

    setUp(() {
      // Only the first receive address is listed; LWK does not expose change
      // addresses, so any other wallet output is outside this listing.
      when(() => lwkWallet.addressLastUnused()).thenAnswer(
        (_) async =>
            const lwk.Address(standard: '', confidential: '', index: 0),
      );
      when(() => lwkWallet.address(index: 0)).thenAnswer(
        (_) async => const lwk.Address(
          standard: 'tex1receive',
          confidential: 'tlq1receive',
          index: 0,
        ),
      );
    });

    // Regression (Pixel 6a, txid e04d3380…): a MAX send to an address of the
    // same wallet that is not a listed receive address left a single wallet
    // output, and the details screen showed "Send 0 sats".
    test(
      'a redeposit with one unlisted L-BTC output shows its value',
      () async {
        expect(await amountOf(walletTx([owned('tlq1change', 8494)])), 8494);
      },
    );

    test('a listed receive output stays apart from the change', () async {
      final tx = walletTx([
        owned('tlq1receive', 5000),
        owned('tlq1change', 3494, vout: 1),
      ]);
      expect(await amountOf(tx), 5000);
    });

    test('two unlisted outputs stay unresolved', () async {
      final tx = walletTx([
        owned('tlq1internal', 1000),
        owned('tlq1change', 7494, vout: 1),
      ]);
      expect(await amountOf(tx), 0);
    });

    test('an unlisted output of another asset is not counted', () async {
      final tx = walletTx([owned('tlq1change', 8494, asset: 'other-asset')]);
      expect(await amountOf(tx), 0);
    });

    test('a fee-only balance that is not a redeposit is unchanged', () async {
      final tx = walletTx([owned('tlq1change', 8494)], kind: 'outgoing');
      expect(await amountOf(tx), 0);
    });

    test('an incoming transaction keeps its balance', () async {
      final tx = walletTx(
        [owned('tlq1receive', 5000)],
        kind: 'incoming',
        balance: 5000,
      );
      expect(await amountOf(tx), 5000);
    });
  });
}
