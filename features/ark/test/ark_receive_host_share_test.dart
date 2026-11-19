import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_receive_flow_test.dart' show app;
import 'ark_receive_share_test.dart' show payload, ready, share;
import 'fake_ark_client.dart';

void main() {
  testWidgets('host effect starts only on the current explicit sheet action', (
    tester,
  ) async {
    final destination = payload(value: ' public-exact-ark-text ');
    final client = FakeArkClient()..destination = Ok(destination);
    final owner = ready(client);
    await owner.request(lightning: false, amount: '');
    final values = <String>[];
    final checks = <bool Function()>[];
    final contexts = <BuildContext>[];
    Future<void> effect(
      BuildContext context,
      String value, {
      required bool Function() isCurrent,
    }) async {
      contexts.add(context);
      values.add(value);
      checks.add(isCurrent);
    }

    await tester.pumpWidget(app(ArkReceiveScreen(cubit: owner, share: effect)));
    await tester.pumpAndSettle();
    expect(values, isEmpty);
    final buttonA = await share(tester);
    buttonA.onPressed();
    expect(values, [destination.value]);
    expect(checks.single(), true);
    Navigator.of(contexts.single).pop();
    await tester.pumpAndSettle();
    expect(checks.single(), false);
    buttonA.onPressed();
    expect(values, hasLength(1));
    final buttonB = await share(tester);
    buttonB.onPressed();
    expect(values, hasLength(2));
    final covering = Navigator.of(contexts.last)
        .push<void>(MaterialPageRoute(builder: (_) => const SizedBox.shrink()));
    await tester.pumpAndSettle();
    buttonB.onPressed();
    expect(checks.last(), false);
    expect(values, hasLength(2));
    Navigator.of(contexts.last).pop();
    await covering;
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(ArkReceiveScreen(cubit: owner)));
    await tester.pumpAndSettle();
    expect(checks.last(), false);
    buttonB.onPressed();
    expect(values, hasLength(2));
    expect(client.calls, ['receive']);
  });
}
