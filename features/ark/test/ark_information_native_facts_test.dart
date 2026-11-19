import 'package:ark/ark.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/ui/ark_information_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
import 'package:flutter_test/flutter_test.dart';

import 'ark_information_widget_test.dart' show app, config, details;
import 'ark_operations_test.dart' show account;

void main() {
  for (final endpoint in ['matching', 'foreign', 'legacy']) {
    testWidgets(
      'native display facts require their configured endpoint $endpoint',
      (tester) async {
        final uri = switch (endpoint) {
          'matching' => config().arkUrl,
          'foreign' => Uri.parse('https://another.example/ark'),
          _ => null,
        };
        await tester.pumpWidget(
          app(
            ArkInformationScreen(
              config: config(),
              snapshot: ArkSnapshot(
                account: account(),
                revision: 1,
                observedAt: DateTime.utc(2026),
                serverInfo: ArkServerInfo(
                  publicKey: 'cached-public-key',
                  serverUri: uri,
                  vtxoExitDelta: 13,
                  htlcSendExpiryDelta: 29,
                  htlcExpiryDelta: 41,
                  roundNonceCount: 7,
                ),
              ),
              serverExitDelta: endpoint == 'matching'
                  ? (account(), config().arkUrl, 13)
                  : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final shown = details(tester);
        expect(
          shown['VTXO exit delta'],
          endpoint == 'matching' ? '13 blocks' : 'Unavailable',
        );
        expect(
          shown['Outgoing HTLC expiry delta'],
          endpoint == 'matching' ? '29 blocks' : 'Unavailable',
        );
        expect(
          shown['Lightning / Ark HTLC expiry difference'],
          endpoint == 'matching' ? '41 blocks' : 'Unavailable',
        );
        expect(
          shown['Nonces per round'],
          endpoint == 'matching' ? '7' : 'Unavailable',
        );
        expect(
          shown['Server public key'],
          endpoint == 'foreign' ? 'Unavailable' : 'cached-public-key',
        );
        expect(find.text('Online'), findsNothing);
        expect(find.text('Offline'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final value in <int?>[null, -1, 0]) {
    testWidgets(
      'native optional display preserves zero but refuses invalid $value',
      (tester) async {
        await tester.pumpWidget(
          app(
            ArkInformationScreen(
              config: config(),
              snapshot: ArkSnapshot(
                account: account(),
                revision: 1,
                observedAt: DateTime.utc(2026),
                serverInfo: ArkServerInfo(
                  publicKey: 'key',
                  serverUri: config().arkUrl,
                  htlcSendExpiryDelta: value,
                  htlcExpiryDelta: value,
                  roundNonceCount: value,
                ),
              ),
              serverExitDelta: value == null
                  ? null
                  : (account(), config().arkUrl, value),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final shown = details(tester);
        final blocks = value == 0 ? '0 blocks' : 'Unavailable';
        expect(shown['VTXO exit delta'], blocks);
        expect(shown['Outgoing HTLC expiry delta'], blocks);
        expect(shown['Lightning / Ark HTLC expiry difference'], blocks);
        expect(shown['Nonces per round'], value == 0 ? '0' : 'Unavailable');
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final failure in <ArkFailure>[
    const ArkFeatureStorageFailure(),
    const ArkAccountRecoveryFailure(),
  ]) {
    testWidgets(
      'non-network failure never invents offline: ${failure.runtimeType}',
      (tester) async {
        var retries = 0;
        await tester.pumpWidget(
          app(
            ArkInformationScreen(
              config: config(),
              snapshot: null,
              failure: failure,
              onRetry: () => retries++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Can’t reach the Ark server'), findsNothing);
        expect(find.text('Offline'), findsNothing);
        await tester.tap(find.widgetWithText(BullButton, 'Retry'));
        expect(retries, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
