import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork, Sats;

/// Tests for the payjoin gating on [ReceiveState.isPayjoinLoading] and its
/// downstream effect on [ReceiveState.paymentRequest]: with payjoin disabled
/// globally, the bloc never creates a session and never sets an exception,
/// so without the [ReceiveState.payjoinGloballyEnabled] gate the QR data
/// would wait for a payjoin forever and never render — and payjoin is
/// disabled by default, so that would be every fresh install's receive
/// screen.
void main() {
  // Defaults to a confirmed balance: most tests in this file are about the
  //  payjoinGloballyEnabled semantics, not the balance one — a zero default
  //  would make isPayjoinLoading false for a reason unrelated to what each
  //  test names. Tests about isPayjoinAwaitingFunds override it explicitly.
  Wallet localWallet({BigInt? balanceSat}) => Wallet(
    origin: 'test-origin',
    network: Network.bitcoinMainnet,
    xpubFingerprint: '00000000',
    scriptType: ScriptType.bip84,
    xpub: '',
    externalPublicDescriptor: '',
    internalPublicDescriptor: '',
    signer: SignerEntity.local,
    signerDevice: null,
    balanceSat: balanceSat ?? BigInt.from(50000),
    // hasUtxos gates on confirmedBalanceSat, not balanceSat — mirror it here
    // so these tests keep exercising the isPayjoinLoading/isPayjoinAwaitingFunds
    // semantics they name, not the confirmed-vs-total distinction.
    confirmedBalanceSat: balanceSat ?? BigInt.from(50000),
  );

  WalletAddress address() => WalletAddress(
    walletId: 'w1',
    index: 0,
    address: 'bc1qtestaddress',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  // payjoinAttemptSettled defaults to true — "the bloc has finished deciding".
  // Tests about the QR's composition are not about the loading gate, and a
  // false default would make paymentRequest empty for a reason unrelated to
  // what each of them names. The gate's own tests set it explicitly.
  ReceiveState buildState({
    required bool? payjoinGloballyEnabled,
    BigInt? balanceSat,
    PayjoinReceiverSession? payjoin,
    bool payjoinAttemptSettled = true,
  }) => ReceiveState(
    type: ReceiveType.bitcoin,
    wallet: localWallet(balanceSat: balanceSat),
    bitcoinAddress: address(),
    payjoinGloballyEnabled: payjoinGloballyEnabled,
    payjoin: payjoin,
    payjoinAttemptSettled: payjoinAttemptSettled,
  );

  // The gate is now a single fact recorded by ReceiveBloc
  // ([ReceiveState.payjoinAttemptSettled]) instead of a derivation over the
  // reasons a session might never arrive. That the bloc actually sets it on
  // every path — payjoin disabled, watch-only wallet, empty wallet, creation
  // failure — is what receive_bloc_test.dart's "payjoin loading gate" group
  // asserts; those cases are no longer expressible here, and must not be
  // re-derived here either, or this getter grows the guards back.
  group('ReceiveState.isPayjoinLoading', () {
    test('loading while the payjoin question is still open: the QR must not '
        'flash an address-only URI and then swap to a pj= BIP21', () {
      final state = buildState(
        payjoinGloballyEnabled: true,
        payjoinAttemptSettled: false,
      );

      expect(state.isPayjoinLoading, isTrue);
    });

    test('not loading once settled with no session — whatever the reason '
        'there is none, nothing must keep waiting for one', () {
      final state = buildState(payjoinGloballyEnabled: true);

      expect(state.isPayjoinLoading, isFalse);
      expect(state.payjoin, isNull);
    });

    test('never loading for a non-bitcoin receive, even while unsettled', () {
      final state = buildState(
        payjoinGloballyEnabled: true,
        payjoinAttemptSettled: false,
      ).copyWith(type: ReceiveType.lightning);

      expect(state.isPayjoinLoading, isFalse);
    });
  });

  group('ReceiveState.paymentRequest payjoin loading gate', () {
    test('stays empty while the payjoin question is still open', () {
      final state = buildState(
        payjoinGloballyEnabled: null,
        payjoinAttemptSettled: false,
      );

      expect(state.paymentRequest, isEmpty);
    });

    test('resolves to the plain address once settled without a session, '
        'instead of waiting forever', () {
      final state = buildState(payjoinGloballyEnabled: false);

      expect(state.paymentRequest, 'bc1qtestaddress');
      expect(state.qrData, 'bc1qtestaddress');
    });
  });

  PayjoinReceiverSession payjoinWith({
    required PayjoinStatus status,
    int? amountSat,
    bool hasRequest = false,
    String? payjoinUri,
  }) => PayjoinReceiverSession(
    status: status,
    id: 'pj1',
    network: BitcoinNetwork.testnet,
    walletId: 'w1',
    payjoinUri: payjoinUri ?? 'bitcoin:tb1qtest?pj=https://payjo.in',
    createdAt: DateTime(2026),
    expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
    amount: amountSat == null ? null : Sats.fromInt(amountSat),
    hasOriginalTransaction: hasRequest,
  );

  group('ReceiveState.paymentRequest BIP21 composition', () {
    // The QR/clipboard string is the user-facing contract of the whole
    // Additional Information flow: the amount parameter must always be
    // denominated in BTC per BIP21 (regardless of the sats/fiat unit the
    // user typed in) and the note must travel as message=.
    test('bitcoin: amount is always in BTC and the note becomes message=', () {
      final state = buildState(
        payjoinGloballyEnabled: false,
      ).copyWith(confirmedAmountSat: 50000, note: 'lunch money');

      final uri = Uri.parse(state.paymentRequest);
      expect(uri.scheme, 'bitcoin');
      expect(uri.path, 'bc1qtestaddress');
      expect(uri.queryParameters['amount'], '0.0005');
      expect(uri.queryParameters['message'], 'lunch money');
    });

    test('bitcoin: an amount alone produces amount= and no message=', () {
      final state = buildState(
        payjoinGloballyEnabled: false,
      ).copyWith(confirmedAmountSat: 123456789);

      final uri = Uri.parse(state.paymentRequest);
      expect(uri.queryParameters['amount'], '1.23456789');
      expect(uri.queryParameters.containsKey('message'), isFalse);
    });

    test('bitcoin: a note alone produces message= and no amount=', () {
      final state = buildState(
        payjoinGloballyEnabled: false,
      ).copyWith(note: 'just a note');

      final uri = Uri.parse(state.paymentRequest);
      expect(uri.queryParameters['message'], 'just a note');
      expect(uri.queryParameters.containsKey('amount'), isFalse);
    });

    test('bitcoin: payjoin params are merged on top of amount and message, '
        'not instead of them', () {
      final state = buildState(
        payjoinGloballyEnabled: true,
        payjoin: payjoinWith(status: PayjoinStatus.started),
      ).copyWith(confirmedAmountSat: 50000, note: 'pj note');

      final uri = Uri.parse(state.paymentRequest);
      expect(uri.queryParameters['amount'], '0.0005');
      expect(uri.queryParameters['message'], 'pj note');
      expect(uri.queryParameters['pj'], 'https://payjo.in');
    });

    test('bitcoin: preserves the encoded BIP77 endpoint fragment', () {
      const payjoinUri =
          'bitcoin:tb1qtest?pj=HTTPS://PAYJO.IN/TXJCGKTKXLUUZ%23EX1WKV8CEC-OH1QYPM59NK2LXXS4890SUAXXYT25Z2VAPHP0X7YEYCJXGWAG6UG9ZU6NQ-RK1Q0DJS3VVDXWQQTLQ8022QGXSX7ML9PHZ6EDSF6AKEWQG758JPS2EV';
      final state = buildState(
        payjoinGloballyEnabled: true,
        payjoin: payjoinWith(
          status: PayjoinStatus.started,
          payjoinUri: payjoinUri,
        ),
      ).copyWith(confirmedAmountSat: 50000, note: 'pj note');

      final output = state.paymentRequest;
      final outputUri = Uri.parse(output);

      expect(
        outputUri.queryParameters['pj'],
        Uri.parse(payjoinUri).queryParameters['pj'],
      );
      expect(output, contains('%23EX1'));
      expect(outputUri.queryParameters['amount'], '0.0005');
      expect(outputUri.queryParameters['message'], 'pj note');
    });

    test('liquid: amount is in BTC (L-BTC) units and the note becomes '
        'message=', () {
      final state = ReceiveState(
        type: ReceiveType.liquid,
        wallet: localWallet(),
        liquidAddress: WalletAddress(
          walletId: 'w1',
          index: 0,
          address: 'lq1qqtestaddress',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        confirmedAmountSat: 50000,
        note: 'liquid note',
      );

      final uri = Uri.parse(state.paymentRequest);
      expect(uri.scheme, 'liquidnetwork');
      expect(uri.queryParameters['amount'], '0.0005');
      expect(uri.queryParameters['message'], 'liquid note');
      expect(uri.queryParameters['assetid'], isNotEmpty);
    });
  });

  group('ReceiveState.isPayjoinFlowOwningNavigation', () {
    test('false for a non-Bitcoin receive type, even with a payjoin set', () {
      final state = ReceiveState(
        type: ReceiveType.liquid,
        payjoin: payjoinWith(status: PayjoinStatus.requested),
      );

      expect(state.isPayjoinFlowOwningNavigation, isFalse);
    });

    test('false when there is no payjoin session at all (watch-only '
        'wallet)', () {
      const state = ReceiveState(type: ReceiveType.bitcoin);

      expect(state.isPayjoinFlowOwningNavigation, isFalse);
    });

    test('false while the payjoin session is still idle (started): a plain '
        'send to this address, unrelated to payjoin, must still navigate '
        'via the generic listener', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.started),
      );

      expect(state.isPayjoinFlowOwningNavigation, isFalse);
    });

    test('true once a request has been received (requested/proposed/'
        'completed/aborted/expired) — the payjoin flow owns navigation '
        'from here', () {
      for (final status in [
        PayjoinStatus.requested,
        PayjoinStatus.proposed,
        PayjoinStatus.completed,
        PayjoinStatus.aborted,
        PayjoinStatus.expired,
      ]) {
        final state = ReceiveState(
          type: ReceiveType.bitcoin,
          payjoin: payjoinWith(status: status, hasRequest: true),
        );

        expect(
          state.isPayjoinFlowOwningNavigation,
          isTrue,
          reason: 'status: $status',
        );
      }
    });

    test('false when an idle receiver expires before any sender request', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.expired),
      );

      expect(state.isPayjoinFlowOwningNavigation, isFalse);
    });
  });

  group('ReceiveState.isPayjoinAwaitingFunds', () {
    test('true when payjoin is enabled globally but this wallet has no '
        'confirmed balance yet', () {
      final state = buildState(
        payjoinGloballyEnabled: true,
        balanceSat: BigInt.zero,
      );

      expect(state.isPayjoinAwaitingFunds, isTrue);
    });

    test('false when the wallet already has a confirmed balance (the '
        'normal loading/available case)', () {
      final state = buildState(payjoinGloballyEnabled: true);

      expect(state.isPayjoinAwaitingFunds, isFalse);
    });

    test('false when payjoin is disabled globally, regardless of balance', () {
      final state = buildState(
        payjoinGloballyEnabled: false,
        balanceSat: BigInt.zero,
      );

      expect(state.isPayjoinAwaitingFunds, isFalse);
    });

    test('false for a non-bitcoin receive type', () {
      const state = ReceiveState(
        type: ReceiveType.liquid,
        payjoinGloballyEnabled: true,
      );

      expect(state.isPayjoinAwaitingFunds, isFalse);
    });

    test('false once a payjoin session already exists', () {
      final state = buildState(
        payjoinGloballyEnabled: true,
        balanceSat: BigInt.zero,
        payjoin: payjoinWith(status: PayjoinStatus.requested),
      );

      expect(state.isPayjoinAwaitingFunds, isFalse);
    });
  });

  group('ReceiveState.isPayjoinBelowMinimum', () {
    test('true when the session aborted below the configured minimum', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.aborted, amountSat: 5000),
        payjoinMinAmountSat: 10000,
      );

      expect(state.isPayjoinBelowMinimum, isTrue);
    });

    test('false when the aborted amount is exactly the minimum', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.aborted, amountSat: 10000),
        payjoinMinAmountSat: 10000,
      );

      expect(state.isPayjoinBelowMinimum, isFalse);
    });

    test('false when below the minimum but not aborted (still requested)', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.requested, amountSat: 5000),
        payjoinMinAmountSat: 10000,
      );

      expect(state.isPayjoinBelowMinimum, isFalse);
    });

    test('false when the minimum is unknown (settings not read yet)', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        payjoin: payjoinWith(status: PayjoinStatus.aborted, amountSat: 5000),
        payjoinMinAmountSat: null,
      );

      expect(state.isPayjoinBelowMinimum, isFalse);
    });
  });

  group('ReceiveState requested-amount payjoin suppression', () {
    // Settled: these tests are about amount-based suppression of an existing
    // session, not about the loading gate.
    ReceiveState payjoinState({int? confirmedAmountSat}) => ReceiveState(
      type: ReceiveType.bitcoin,
      wallet: localWallet(),
      bitcoinAddress: address(),
      payjoinGloballyEnabled: true,
      payjoinMinAmountSat: 10000,
      payjoin: payjoinWith(status: PayjoinStatus.requested),
      confirmedAmountSat: confirmedAmountSat,
      payjoinAttemptSettled: true,
    );

    test('canPayjoin stays true with no amount entered', () {
      expect(payjoinState().canPayjoin, isTrue);
      expect(payjoinState().isRequestedAmountBelowPayjoinMinimum, isFalse);
      expect(payjoinState().isPayjoinSuppressedByAmount, isFalse);
    });

    test(
      'canPayjoin stays true when the amount is at or above the minimum',
      () {
        expect(payjoinState(confirmedAmountSat: 10000).canPayjoin, isTrue);
        expect(payjoinState(confirmedAmountSat: 20000).canPayjoin, isTrue);
      },
    );

    test('canPayjoin drops to false when the requested amount is below the '
        'minimum, and the QR no longer advertises pj=', () {
      final state = payjoinState(confirmedAmountSat: 5000);

      expect(state.isRequestedAmountBelowPayjoinMinimum, isTrue);
      expect(state.canPayjoin, isFalse);
      expect(state.isPayjoinSuppressedByAmount, isTrue);
      expect(state.paymentRequest.contains('pj='), isFalse);
      // The amount is still in the URI — only payjoin is suppressed.
      expect(state.paymentRequest.contains('amount='), isTrue);
    });

    test('suppression lifts as soon as the amount is raised back to the '
        'minimum (no session teardown needed)', () {
      expect(payjoinState(confirmedAmountSat: 5000).canPayjoin, isFalse);
      expect(payjoinState(confirmedAmountSat: 10000).canPayjoin, isTrue);
      expect(
        payjoinState(confirmedAmountSat: 10000).paymentRequest,
        contains('pj='),
      );
    });

    test('isPayjoinSuppressedByAmount is false when no payjoin session '
        'exists', () {
      final state = ReceiveState(
        type: ReceiveType.bitcoin,
        wallet: localWallet(),
        bitcoinAddress: address(),
        payjoinMinAmountSat: 10000,
        confirmedAmountSat: 5000,
      );

      expect(state.isPayjoinSuppressedByAmount, isFalse);
    });
  });
}
