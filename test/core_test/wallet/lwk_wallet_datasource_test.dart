import 'package:primitives/primitives.dart' show Ok;
import 'package:transactions/testing.dart';
import 'package:primitives/primitives.dart' show LiquidNetwork;
import 'package:sync/sync.dart' show WalletKey, LiquidCoin;
import 'package:sync/testing.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLwkWallet extends Mock implements lwk.Wallet {}

// The Liquid builds moved into sync: see
// packages/sync/test/spend/liquid_spend_test.dart.
void main() {
  final key = WalletKey(id: 'liquid-wallet', network: LiquidNetwork.testnet);
  late _MockLwkWallet lwkWallet;
  late WalletHistoryDatasource values;

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
    values = WalletHistoryDatasource(
      load: (key) async => Ok(await testWalletFromNative(lwkWallet, key: key)),
    );
    // The frame reads every value; tests override what they exercise.
    when(() => lwkWallet.balances()).thenAnswer(
      (_) async => [
        lwk.WalletBalance(
          assetId: AssetConstants.lbtcTestnet,
          value: BigInt.zero,
        ),
      ],
    );
    when(() => lwkWallet.utxos()).thenAnswer((_) async => []);
    when(() => lwkWallet.txs()).thenAnswer((_) async => []);
    when(() => lwkWallet.addressLastUnused()).thenAnswer(
      (_) async =>
          const lwk.Address(standard: 's', confidential: 'c', index: 0),
    );
    when(() => lwkWallet.address(index: any(named: 'index'))).thenAnswer(
      (_) async =>
          const lwk.Address(standard: 's', confidential: 'c', index: 0),
    );
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

  test('lists only L-BTC coins for the wallet network', () async {
    when(() => lwkWallet.utxos()).thenAnswer(
      (_) async => [coin('lbtc'), coin('other-asset', asset: 'other')],
    );

    final handle = await testWalletFromNative(lwkWallet, key: key);
    final coins = handle.coins.now.data;

    expect(coins?.map((coin) => coin.outpoint.txId), ['lbtc']);
    expect((coins?.single as LiquidCoin).blockHeight, 100);
  });

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
      final txs = (await values.getTransactions(key: key))
          .fold((value) => value, (failure) => fail(failure.logCode));
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
