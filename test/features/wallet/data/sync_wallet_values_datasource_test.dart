import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show Network;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Ok;
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' as sync;
import 'package:sync/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const model = WalletModel.publicBdk(
    id: 'values',
    descriptor: 'unused',
    network: Network.bitcoinTestnet,
  );
  // BIP173 test vector: a testnet P2WPKH address.
  const address = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';
  final script = (sync.bitcoinAddressScript(
    address,
    BitcoinNetwork.testnet,
  ) as Ok<Uint8List, sync.SyncFailure>).value;

  sync.BitcoinOutput output(
    int vout,
    int sats, {
    bool own = false,
    String? to,
  }) => sync.BitcoinOutput(
    vout: vout,
    valueSat: BigInt.from(sats),
    scriptPubkey: Uint8List.fromList([vout]),
    address: to,
    isOwn: own,
    isChange: false,
  );

  sync.BitcoinTransaction tx(
    String txid, {
    List<sync.BitcoinInput> inputs = const [],
    required List<sync.BitcoinOutput> outputs,
    required int sent,
    required int received,
    int? fee = 100,
  }) => sync.BitcoinTransaction(
    txid: txid,
    feeSat: fee,
    vsize: 141,
    confirmationTime: null,
    inputs: inputs,
    outputs: outputs,
    sentSat: sent,
    receivedSat: received,
    isExplicitlyRbf: false,
  );

  SyncWalletValuesDatasource over({
    List<sync.ChainTransaction> transactions = const [],
    List<sync.Coin> coins = const [],
    List<Uint8List> ownedScripts = const [],
  }) => SyncWalletValuesDatasource(
    load: (key) => testWallet(
      key: key,
      balances: sync.Balances(
        confirmedSat: BigInt.from(7),
        immatureSat: BigInt.zero,
        trustedPendingSat: BigInt.zero,
        untrustedPendingSat: BigInt.zero,
        spendableSat: BigInt.from(7),
        totalSat: BigInt.from(7),
      ),
      transactions: transactions,
      coins: coins,
      ownedScripts: ownedScripts,
    ),
  );

  test('a wallet that cannot load never reads as a zero balance', () async {
    final values = SyncWalletValuesDatasource(
      load: (_) async =>
          throw const WalletSnapshotException(sync.SyncBusyFailure()),
    );
    await expectLater(
      values.getBalance(wallet: model),
      throwsA(isA<WalletSnapshotException>()),
    );
    expect((await over().getBalance(wallet: model)).totalSat, BigInt.from(7));
  });

  test('history shapes direction, ownership and the paid amount', () async {
    final values = over(
      transactions: [
        tx(
          'funding',
          outputs: [output(0, 1000, own: true), output(1, 50)],
          sent: 0,
          received: 1000,
        ),
        tx(
          'payment',
          inputs: [
            sync.BitcoinInput(
              previousOutput: (txId: 'funding', vout: 0),
              scriptSig: Uint8List(0),
            ),
          ],
          outputs: [
            output(0, 600, to: address),
            output(1, 300, own: true),
          ],
          sent: 1000,
          received: 300,
        ),
      ],
    );
    final history = await values.getTransactions(wallet: model);
    final payment = history.firstWhere((tx) => tx.txId == 'payment');
    expect(payment.isIncoming, isFalse);
    expect(payment.isToSelf, isFalse);
    expect(payment.inputs.single.isOwn, isTrue);
    // What reached the recipient: sent - received - fee.
    expect(payment.amountSat, 600);
    final funding = history.firstWhere((tx) => tx.txId == 'funding');
    expect(funding.isIncoming, isTrue);
    expect(funding.amountSat, 1000);
    expect(
      (await values.getTransactions(
        wallet: model,
        toAddress: address,
      )).map((tx) => tx.txId),
      ['payment'],
    );
  });

  test('an unpriced transaction fails history, not balances', () async {
    final values = over(
      transactions: [
        tx('foreign', outputs: [output(0, 5)], sent: 0, received: 5, fee: null),
      ],
    );
    await expectLater(
      values.getTransactions(wallet: model),
      throwsA(isA<WalletSnapshotException>()),
    );
    expect((await values.getBalance(wallet: model)).totalSat, BigInt.from(7));
  });

  test('address ownership comes from the exact index', () async {
    final values = over(ownedScripts: [script]);
    expect(await values.areAddressesMine([address], wallet: model), isTrue);
    expect(await values.isMine(script, wallet: model), isTrue);
    expect(await over().areAddressesMine([address], wallet: model), isFalse);
  });

  test('exact coins keep the Bitcoin coin fields', () async {
    final values = over(
      coins: [
        sync.BitcoinCoin(
          outpoint: (txId: 'coin', vout: 2),
          amountSat: BigInt.from(900),
          scriptPubkey: script,
          address: address,
          keychain: sync.Keychain.internal,
          confirmations: 3,
        ),
      ],
    );
    final coin =
        (await values.getExactUtxos(wallet: model)).single
            as BitcoinWalletUtxoModel;
    expect(coin.txId, 'coin');
    expect(coin.vout, 2);
    expect(coin.amountSat, BigInt.from(900));
    expect(coin.isExternalKeyChain, isFalse);
    expect(coin.confirmations, 3);
    expect(await values.getAddressBalancesSat(wallet: model), {
      address: BigInt.from(900),
    });
  });
}
