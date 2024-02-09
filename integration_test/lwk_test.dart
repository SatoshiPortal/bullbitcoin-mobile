import 'dart:async';

import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwk_dart/lwk_dart.dart';
import 'package:path_provider/path_provider.dart';

import 'lwk_test.data.dart';

late LiquidWallet wallet;

const testTimeout = Timeout(Duration(minutes: 30));

void main() {
  setUpAll(() async {
    await setupWallet();
  });

  group('BTC-LN Submarince', () {
    test('getBalance', () async {
      final Balance b = await wallet.balance();
      print(b.lbtc);
    });

    test('sendAmount', () async {
      try {
        final String txid = await sendLiquid(
          'tlq1qqgtpd4256nmfcp0et0tz2v5emnt0ruman92s0r7m8z3q59vdzg5hcdhdalz5d09hgwdkqr24ar7hfspm906e25ce3tj4r6zkd',
          3000,
        );
        print(txid);
      } catch (e) {
        print(e);
      }
    });

    test(
      'Neg: Send less on-chain sats',
      () async {
        const invoice =
            'lntb32110n1pjutpttpp5la5z3zhtks8ud2j7xwy7rux4gpd4av7p5g2tcnfnvqxk434lextqdqqcqzzsxqyjw5qsp57tnhwa2myvg9us54ejh6zuwhxwkw7nsnrcv2jqsq7x4xmwxmymwq9qyyssqv8p4yn3p75weehhaz24lllrsdav83llg0d2vvz9h7gjysang9phrxkehjhx3stnx58qygljwnpwyfx06sfpghyelvxwug9zsz957kgsprwjfg0';

        final LbtcLnSwap lbtcLnSubmarine = await setupLSubmarine(invoice);

        const expectedSecretKey =
            '9b496356fbb59d95656acc879a5d7a9169eb3d77e5b7c511aeb827925e5b49e9';

        final swap = lbtcLnSubmarine.lbtcLnSwap;
        print('SWAP CREATED SUCCESSFULLY: ${swap.id}');

        final completer = Completer();
        final receivedEvents = <dynamic>[];
        final api = await BoltzApi.newBoltzApi();
        final sub = api.getSwapStatusStream(swap.id).listen((event) {
          receivedEvents.add(event);
          if (event.status == SwapStatus.txnLockupFailed) {
            completer.complete();
          }
        });

        final paymentDetails = await lbtcLnSubmarine.paymentDetails();
        expect(swap.keys.secretKey, expectedSecretKey);
        final outAddress = paymentDetails.split(':')[0];
        final outAmount = int.parse(paymentDetails.split(':')[1]);
        print('Expected: $outAmount. But sending only 1000 to: $outAddress');
        final txid = await sendLiquid(outAddress, 1000);
        print('TXID: $txid');

        await completer.future;

        await sub.cancel();

        expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
        expect(receivedEvents[1].status, equals(SwapStatus.txnLockupFailed));

        // TODO: Getting refund
      },
      timeout: testTimeout,
    );

    test(
      'Positive',
      () async {
        const invoice =
            'lntb32140n1pjutpwwpp502z6q8r03xeyy53n7ytg0926eem4kqc88wnlxsjnz6652cuclqusdqqcqzzsxqyjw5qsp56n8842cg27s6l8x3exe0ukg6tkp60cw9qnsm95fuvatrulh80dpq9qyyssq2msnf23jrv4npzyhrms52aezy7yyy9d9qee5zr4qvz48mfp8kn3xd09ry7ewlt4nhj69r7mffdflmxp6d8cvhh0jac7dw08qae63d4gp52fwd2';

        final LbtcLnSwap lbtcLnSubmarine = await setupLSubmarine(invoice);

        const expectedSecretKey =
            '9b496356fbb59d95656acc879a5d7a9169eb3d77e5b7c511aeb827925e5b49e9';

        final swap = lbtcLnSubmarine.lbtcLnSwap;
        print('SWAP CREATED SUCCESSFULLY: ${swap.id}');

        final completer = Completer();
        final receivedEvents = <dynamic>[];
        final api = await BoltzApi.newBoltzApi();
        final sub = api.getSwapStatusStream(swap.id).listen((event) {
          receivedEvents.add(event);
          if (event.status == SwapStatus.txnClaimed) {
            completer.complete();
          }
        });

        final paymentDetails = await lbtcLnSubmarine.paymentDetails();
        expect(swap.keys.secretKey, expectedSecretKey);
        final outAddress = paymentDetails.split(':')[0];
        final outAmount = int.parse(paymentDetails.split(':')[1]);
        print('Sending expected amount $outAmount to $outAddress');
        final txid = await sendLiquid(outAddress, outAmount);
        print('TXID: $txid');

        await completer.future;

        await sub.cancel();

        expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
        expect(receivedEvents[1].status, equals(SwapStatus.txnMempool));
        expect(receivedEvents[2].status, equals(SwapStatus.invoicePending));
        expect(receivedEvents[3].status, equals(SwapStatus.invoicePaid));
        expect(receivedEvents[4].status, equals(SwapStatus.txnClaimed));
      },
      timeout: testTimeout,
    );
  });
}

Future<String> getDbDir() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/lwk-db';
    return path;
  } catch (e) {
    print('Error getting current directory: $e');
    rethrow;
  }
}

Future<LiquidWallet> setupWallet() async {
  final dbPath = await getDbDir();
  wallet = await LiquidWallet.create(
    mnemonic: fundingLWalletMnemonic,
    network: lNetwork,
    dbPath: dbPath,
  );
  await wallet.sync(lElectrumUrl);

  return wallet;
}

Future<String> sendLiquid(String address, int amount) async {
  const absFee = 300.0;
  final pset = await wallet.build(
    sats: amount,
    outAddress: address,
    absFee: absFee,
  );
  // final decodedPset = await wallet.decode(pset: pset);
  // print('Amount: ${decodedPset.balances.lbtc} , Fee: ${decodedPset.fee}');
  final signedTxBytes =
      await wallet.sign(network: lNetwork, pset: pset, mnemonic: fundingLWalletMnemonic);
  final tx = await wallet.broadcast(
    electrumUrl: lElectrumUrl,
    txBytes: signedTxBytes,
  );
  // print(tx);
  await wallet.sync(lElectrumUrl);
  return tx;
}

Future<LbtcLnSwap> setupLSubmarine(String invoice) async {
  const amount = 100000;
  final fees = await AllSwapFees.estimateFee(boltzUrl: boltzUrl, outputAmount: amount);

  final lbtcLnSubmarineSwap = await LbtcLnSwap.newSubmarine(
    mnemonic: swapMnemonic,
    index: swapIndex,
    invoice: invoice,
    network: Chain.LiquidTestnet,
    electrumUrl: electrumUrl,
    boltzUrl: boltzUrl,
    pairHash: fees.lbtcPairHash,
  );

  return lbtcLnSubmarineSwap;
}
