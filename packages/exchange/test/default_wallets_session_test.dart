import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

const _session = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 3,
  sessionId: 's',
);
const _other = ExchangeSession(
  environment: ExchangeEnvironment.testnet,
  epoch: 4,
  sessionId: 't',
);
const _wallets = DefaultWallets(
  bitcoin: DefaultWallet(
    recipientId: 'r1',
    walletType: BtcNetwork.bitcoin,
    address: 'bc1qsaved',
  ),
);

Exchange _exchange({
  Future<Result<DefaultWallets, ExchangeFailure>> Function()? get,
  Future<ExchangeWrite<DefaultWallet>> Function()? save,
  Future<ExchangeWrite<void>> Function()? unset,
  ExchangeWriteGate? gate,
}) => exchangeForTesting(
  access: fixedAccessForTesting(const ExchangeAccessSignedIn(_session)),
  getDefaultWallets: get,
  saveDefaultWallet: save == null
      ? null
      : ({required walletType, required address, existingRecipientId}) =>
            save(),
  deleteDefaultWallet: unset == null
      ? null
      : ({required recipientId, required walletType, required address}) =>
            unset(),
  writeGate: gate,
);

void main() {
  group('readDefaultWallets (DW-6)', () {
    test('reads the wallets of the current session', () async {
      final read = await _exchange(get: () async => const Ok(_wallets))
          .readDefaultWallets(_session);
      expect(read, isA<ReadGot<DefaultWallets>>());
    });

    test('another session is never read', () async {
      final read = await _exchange().readDefaultWallets(_other);
      expect(
        read,
        isA<ReadSessionRejected<DefaultWallets>>().having(
          (r) => r.why,
          'why',
          ExchangeSessionRejection.sessionChanged,
        ),
      );
    });

    for (final (failure, matcher) in [
      (
        const ExchangeNotAuthenticatedFailure(),
        isA<ReadSessionRejected<DefaultWallets>>(),
      ),
      (
        const ExchangeSessionRejectedFailure(ExchangeSessionRejection.server),
        isA<ReadSessionRejected<DefaultWallets>>(),
      ),
      (
        const ExchangeOperationStaleFailure(),
        isA<ReadSessionRejected<DefaultWallets>>(),
      ),
      (
        const ExchangeNetworkFailure(),
        isA<ReadUnreachable<DefaultWallets>>().having(
          (r) => r.isNetwork,
          'isNetwork',
          true,
        ),
      ),
      (
        const ExchangeUnexpectedFailure(),
        isA<ReadUnreachable<DefaultWallets>>().having(
          (r) => r.isNetwork,
          'isNetwork',
          false,
        ),
      ),
    ]) {
      test('${failure.runtimeType} is a failed read, never empty', () async {
        final read = await _exchange(get: () async => Err(failure))
            .readDefaultWallets(_session);
        expect(read, matcher);
      });
    }
  });

  group('saveSessionDefaultWallet', () {
    test('runs through the write gate', () async {
      final read =
          await _exchange(save: () async => WriteDone(_wallets.bitcoin!))
              .saveSessionDefaultWallet(
                _session,
                walletType: BtcNetwork.bitcoin,
                address: 'bc1qsaved',
              );
      expect(
        read,
        isA<GateAdmitted<ExchangeWrite<DefaultWallet>>>().having(
          (g) => g.result,
          'result',
          isA<WriteDone<DefaultWallet>>(),
        ),
      );
    });

    test('is refused while another write of the account runs', () async {
      final gate = ExchangeWriteGate();
      final release = Completer<String>();
      final running = gate.run(
        _session,
        FinancialWriteKind.orderConfirm,
        () => release.future,
      );
      final write = await _exchange(gate: gate).saveSessionDefaultWallet(
        _session,
        walletType: BtcNetwork.bitcoin,
        address: 'bc1q',
      );
      expect(
        write,
        isA<GateRefused<ExchangeWrite<DefaultWallet>>>().having(
          (g) => g.refusal,
          'refusal',
          const WriteGateBusy(FinancialWriteKind.orderConfirm),
        ),
      );
      release.complete('done');
      await running;
    });

    test('a session that is no longer current is not sent', () async {
      final write = await _exchange().saveSessionDefaultWallet(
        _other,
        walletType: BtcNetwork.bitcoin,
        address: 'bc1q',
      );
      expect(
        write,
        isA<GateAdmitted<ExchangeWrite<DefaultWallet>>>().having(
          (g) => g.result,
          'result',
          isA<WriteNotSent<DefaultWallet>>().having(
            (w) => w.reason,
            'reason',
            ExchangeNotSentReason.sessionChanged,
          ),
        ),
      );
    });
  });

  group('unsetSessionDefaultWallet', () {
    for (final answer in <ExchangeWrite<void>>[
      const WriteDone(null),
      const WriteOutcomeUnknown('504'),
      const WriteRefused(ExchangeRefusal(httpStatus: 400)),
    ]) {
      test('passes ${answer.runtimeType} through the gate', () async {
        final write = await _exchange(unset: () async => answer)
            .unsetSessionDefaultWallet(
              _session,
              recipientId: 'r1',
              walletType: BtcNetwork.bitcoin,
              address: 'bc1qsaved',
            );
        expect(
          write,
          isA<GateAdmitted<ExchangeWrite<void>>>().having(
            (g) => g.result,
            'result',
            same(answer),
          ),
        );
      });
    }

    test('a session that is no longer current is not sent', () async {
      final write = await _exchange().unsetSessionDefaultWallet(
        _other,
        recipientId: 'r1',
        walletType: BtcNetwork.bitcoin,
        address: 'bc1qsaved',
      );
      expect(
        write,
        isA<GateAdmitted<ExchangeWrite<void>>>().having(
          (g) => g.result,
          'result',
          isA<WriteNotSent<void>>(),
        ),
      );
    });
  });
}
