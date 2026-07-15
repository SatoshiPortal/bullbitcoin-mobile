import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for [ReceiveState.isPayjoinFlowOwningNavigation] — the getter the
/// receive ShellRoute's generic "payment received" navigation defers to, so
/// it doesn't race ReceivePayjoinInProgressScreen's own navigation (a real
/// payjoin completion auto-navigates there; a plain-broadcast fallback
/// completion stays on that screen for a manual "View Details" tap).
void main() {
  PayjoinReceiver payjoinWith({required PayjoinStatus status}) =>
      Payjoin.receiver(
            status: status,
            id: 'pj1',
            isTestnet: true,
            walletId: 'w1',
            pjUri: 'bitcoin:tb1qtest?pj=https://payjo.in',
            createdAt: DateTime(2026),
            expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
          )
          as PayjoinReceiver;

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
        'completed/expired) — the payjoin flow owns navigation from here', () {
      for (final status in [
        PayjoinStatus.requested,
        PayjoinStatus.proposed,
        PayjoinStatus.completed,
        PayjoinStatus.expired,
      ]) {
        final state = ReceiveState(
          type: ReceiveType.bitcoin,
          payjoin: payjoinWith(status: status),
        );

        expect(
          state.isPayjoinFlowOwningNavigation,
          isTrue,
          reason: 'status: $status',
        );
      }
    });
  });
}
