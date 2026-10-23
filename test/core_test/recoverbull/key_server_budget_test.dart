import 'package:bb_mobile/core/recoverbull/domain/key_server_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The cause mapping relies on Tor's budget expiring before the probe deadline: the other way round, every Tor failure would surface as a bare timeout.
  test('the probe deadline stays 10% above the Tor connect budget', () {
    expect(keyServerProbeDeadline, greaterThan(keyServerConnectBudget));
    expect(keyServerProbeDeadline, const Duration(seconds: 44));
  });
}
