import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwk_dart/lwk_dart.dart';

import 'lwk_test.data.dart';
import 'test_base.dart';

late LiquidWallet wallet;

const testTimeout = Timeout(Duration(minutes: 30));

void main() {
  setUpAll(() async {
    wallet = await setupWallet();
  });

  group('General', () {
    test('getBalance', () async {
      final Balance b = await wallet.balance();
      print(b.lbtc);
    });

    test('sendAmount', () async {
      try {
        final String txid = await sendLiquid(
          wallet,
          baconWalletAddress,
          3000,
        );
        print(txid);
      } catch (e) {
        print(e);
      }
    });
  });
  group('LBTC-LN Submarince', () {
    test('Neg: Minimum limit (1k sats)', () async {
      // An invoice with <1k sats
      await expectLater(
        () async => await setupLSubmarine(invoice600),
        throwsA(
          predicate((e) {
            return e is BoltzError &&
                e.kind == 'BoltzApi' &&
                e.message == '{"error":"$invoice600Amount is less than minimal of 1000"}';
          }),
        ),
      );
    });

    test('Neg: Maximum limit (25m sats)', () async {
      // An invoice with >25m sats
      await expectLater(
        () async => await setupLSubmarine(invoice26m),
        throwsA(
          predicate((e) {
            return e is BoltzError &&
                e.kind == 'BoltzApi' &&
                e.message == '{"error":"$invoice26mAmount is exceeds maximal of 25000000"}';
          }),
        ),
      );
    });

    test('Neg: Used Invoice', () async {
      await expectLater(
        () async => await setupLSubmarine(usedInvoice),
        throwsA(
          predicate((e) {
            return e is BoltzError &&
                e.kind == 'BoltzApi' &&
                e.message == '{"error":"a swap with this invoice exists already"}';
          }),
        ),
      );
    });

    test('Neg: Expired invoice', () async {
      await expectLater(
        () async => await setupLSubmarine(expiredInvoice),
        throwsA(
          predicate((e) {
            return e is BoltzError &&
                e.kind == 'BoltzApi' &&
                e.message == '{"error":"the provided invoice expired already"}';
          }),
        ),
      );
    });

    test('Neg: Invalid invoice', () async {
      await expectLater(
        () async => await setupLSubmarine(invalidInvoice),
        throwsA(
          predicate((e) {
            print(e);
            return e is BoltzError &&
                e.kind == 'BoltzApi' &&
                e.message == '{"error":"No separator character for lntbinvalidinvoice"}';
          }),
        ),
      );
    });

    test(
      'Neg: Send less on-chain sats',
      () async {
        const invoice =
            'lntb12360n1pjuty4wpp5eg9ap5x0un6lhxsklhelqvlg9wm3xphgm5ccdtu0v2awh38v7wlsdqqcqzzsxqyjw5qsp5x22jz7yusynfyycxsdw870pmztcx2655cdzjs6m2vz6h3k8d5u8q9qyyssqk3lz5m3xsm774zlngkwm98jt9qw7p5mgtmnc04q7jfl5ffk7j0u4m6ggh6d3h4ltntmnjfful7gx92suf39adjrdntemxxgt2nd7zxqqu9vs2m';

        final LbtcLnSwap lbtcLnSubmarine = await setupLSubmarine(invoice);

        const expectedSecretKey =
            '9b496356fbb59d95656acc879a5d7a9169eb3d77e5b7c511aeb827925e5b49e9';

        final swap = lbtcLnSubmarine.lbtcLnSwap;
        print('SWAP CREATED SUCCESSFULLY: ${swap.id}');

        final (receivedEvents, completer, sub) =
            await listenForEventInitiate(swap.id, SwapStatus.txnLockupFailed);

        final paymentDetails = await lbtcLnSubmarine.paymentDetails();
        expect(swap.keys.secretKey, expectedSecretKey);
        final outAddress = paymentDetails.split(':')[0];
        final outAmount = int.parse(paymentDetails.split(':')[1]);
        print('Expected: $outAmount. But sending only 1000 to: $outAddress');
        final txid = await sendLiquid(wallet, outAddress, 1000);
        print('TXID: $txid');

        await listenForEventClosure(completer, sub);

        expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
        expect(receivedEvents[1].status, equals(SwapStatus.txnLockupFailed));

        // TODO: Getting refund
      },
      skip: true,
      timeout: testTimeout,
    );

    test(
      'Neg: LN Invoice expires',
      () async {
        const invoice =
            'lntb12330n1pjut2ntpp5ndqw5cn8rwk3dv8nwztsyu4l4gxhttnzvjnwrls0xt3nazvy45fqdqqcqzzsxqzrcsp57ssuj3f9jj7mes4ggy5pd7z68vmcxaexrmyfk5uqfhkmhd2ectzs9qyyssqrtfej2f0mynq95499v3q6wczues6q27g72y3qnwn7y4k6hhgzpvx7lkp04wape39lntf65azghql92qfvec0xvk7hrqrkcuypkty45qpvvkcm6';

        final LbtcLnSwap lbtcLnSubmarine = await setupLSubmarine(invoice);

        const expectedSecretKey =
            '9b496356fbb59d95656acc879a5d7a9169eb3d77e5b7c511aeb827925e5b49e9';

        final swap = lbtcLnSubmarine.lbtcLnSwap;
        print('SWAP CREATED SUCCESSFULLY: ${swap.id}');

        final (receivedEvents, completer, sub) =
            await listenForEventInitiate(swap.id, SwapStatus.txnLockupFailed);

        final paymentDetails = await lbtcLnSubmarine.paymentDetails();
        expect(swap.keys.secretKey, expectedSecretKey);
        final outAddress = paymentDetails.split(':')[0];
        final outAmount = int.parse(paymentDetails.split(':')[1]);
        print('Sending expected amount $outAmount to $outAddress, after Invoice expires (2m)');
        await Future.delayed(const Duration(seconds: 120));
        final txid = await sendLiquid(wallet, outAddress, outAmount);
        print('TXID: $txid');

        await listenForEventClosure(completer, sub);

        expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
        expect(receivedEvents[1].status, equals(SwapStatus.txnMempool));
        expect(receivedEvents[2].status, equals(SwapStatus.invoicePending));
        expect(receivedEvents[3].status, equals(SwapStatus.invoiceFailedToPay));

        // TODO: Getting refund
      },
      skip: true,
      timeout: testTimeout,
    );

    test(
      'Positive',
      () async {
        const invoice =
            'lntb70u1pjut9xmpp5pwqmjsf9a4xstlqvxpzg30zrcvauum5l4tz0a3jy9ck2dv2s9hzsdqqcqzzsxqyjw5qsp5wund45fwl8g4nwp9usyqed6ar66e2qhx9fdv0wzc6vuxc0jyg7zq9qyyssq20nq335yyykpndjduxc7h0dvyvj3jwchfemuf6l03ejjxdrhm2mr228ftpxgme97cvp9ck9clmqpcxwhc7hs54zedqe5fvypcmrtx7cqstzeen';

        final LbtcLnSwap lbtcLnSubmarine = await setupLSubmarine(invoice);

        const expectedSecretKey =
            '9b496356fbb59d95656acc879a5d7a9169eb3d77e5b7c511aeb827925e5b49e9';

        final swap = lbtcLnSubmarine.lbtcLnSwap;
        print('SWAP CREATED SUCCESSFULLY: ${swap.id}');

        final (receivedEvents, completer, sub) =
            await listenForEventInitiate(swap.id, SwapStatus.txnClaimed);

        final paymentDetails = await lbtcLnSubmarine.paymentDetails();
        expect(swap.keys.secretKey, expectedSecretKey);
        final outAddress = paymentDetails.split(':')[0];
        final outAmount = int.parse(paymentDetails.split(':')[1]);
        print('Sending expected amount $outAmount to $outAddress');
        final txid = await sendLiquid(wallet, outAddress, outAmount);
        print('TXID: $txid');

        await listenForEventClosure(completer, sub);

        expect(receivedEvents[0].status, equals(SwapStatus.invoiceSet));
        expect(receivedEvents[1].status, equals(SwapStatus.txnMempool));
        expect(receivedEvents[2].status, equals(SwapStatus.invoicePending));
        expect(receivedEvents[3].status, equals(SwapStatus.invoicePaid));
        expect(receivedEvents[4].status, equals(SwapStatus.txnClaimed));
      },
      skip: true,
      timeout: testTimeout,
    );
  });
}
