import 'package:bb_mobile/features/receive/domain/enums/receive_network_type.dart';
import 'package:bb_mobile/features/receive/domain/receive_advanced_options.dart';
import 'package:bb_mobile/features/receive/domain/receive_lightning_limits.dart';
import 'package:bb_mobile/features/receive/domain/receive_live_amount.dart';
import 'package:test/test.dart';

void main() {
  test(
    'live candidates reject stale amount, wallet, network and invalid state',
    () {
      const original = ReceiveLiveAmount(
        network: ReceiveNetworkType.bitcoin,
        walletId: 'savings',
        canonicalAmount: '25000',
        admitted: true,
      );
      expect(original.canUpdate, isTrue);
      expect(original.stillMatches(original), isTrue);
      for (final next in [
        const ReceiveLiveAmount(
          network: ReceiveNetworkType.bitcoin,
          walletId: 'savings',
          canonicalAmount: '50000',
          admitted: true,
        ),
        const ReceiveLiveAmount(
          network: ReceiveNetworkType.bitcoin,
          walletId: 'spending',
          canonicalAmount: '25000',
          admitted: true,
        ),
        const ReceiveLiveAmount(
          network: ReceiveNetworkType.lightning,
          walletId: 'savings',
          canonicalAmount: '25000',
          admitted: true,
        ),
        const ReceiveLiveAmount(
          network: ReceiveNetworkType.bitcoin,
          walletId: 'savings',
          canonicalAmount: '25000',
          admitted: false,
        ),
      ]) {
        expect(original.stillMatches(next), isFalse);
      }
      const cleared = ReceiveLiveAmount(
        network: ReceiveNetworkType.liquid,
        walletId: 'liquid',
        canonicalAmount: '',
        admitted: true,
      );
      expect(cleared.canUpdate, isTrue);
    },
  );

  test(
    'the summary exposes only applicable active settings, in display order',
    () {
      const options = ReceiveAdvancedOptions(
        network: ReceiveNetworkType.bitcoin,
        walletCount: 2,
        payjoinEnabled: true,
        hasMessage: true,
      );
      expect(options.showWalletPicker, isTrue);
      expect(options.summary, ReceiveAdvancedSummaryPart.values);
      for (final network in [
        ReceiveNetworkType.liquid,
        ReceiveNetworkType.lightning,
      ]) {
        final options = ReceiveAdvancedOptions(
          network: network,
          walletCount: 2,
          payjoinEnabled: true,
          hasMessage: true,
        );
        expect(options.showWalletPicker, isFalse);
        expect(options.summary, [ReceiveAdvancedSummaryPart.message]);
      }
      expect(
        const ReceiveAdvancedOptions(
          network: ReceiveNetworkType.bitcoin,
          walletCount: 1,
          payjoinEnabled: false,
          hasMessage: false,
        ).summary,
        isEmpty,
      );
    },
  );

  test('bounded routes wait for limits and enforce inclusive bounds', () {
    const loading = ReceiveLightningLimits(requiresBounds: true);
    expect(loading.ready, isFalse);
    expect(loading.permits(1000), isFalse);
    const limits = ReceiveLightningLimits(
      requiresBounds: true,
      minimumSat: 1000,
      maximumSat: 10000,
    );
    expect(limits.permits(999), isFalse);
    expect(limits.permits(1000), isTrue);
    expect(limits.permits(10000), isTrue);
    expect(limits.permits(10001), isFalse);
  });

  test(
    'routes with Exchange preserve quote validation outside Boltz bounds',
    () {
      const limits = ReceiveLightningLimits(
        requiresBounds: false,
        minimumSat: 1000,
        maximumSat: 10000,
      );
      expect(limits.permits(1), isTrue);
      expect(limits.permits(10001), isTrue);
      expect(limits.permits(0), isFalse);
    },
  );
}
