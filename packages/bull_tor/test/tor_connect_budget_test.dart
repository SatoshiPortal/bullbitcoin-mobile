import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';

void main() {
  // Callers map Tor's own failure only if its budget expires before their deadline; the other way round, every Tor failure would surface as a bare timeout.
  test('the connect deadline stays 10% above the Tor connect budget', () {
    expect(torConnectDeadline, torConnectBudget * 1.1);
    expect(torConnectDeadline, greaterThan(torConnectBudget));
  });
}
