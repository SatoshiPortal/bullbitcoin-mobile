import 'package:bull_tor/tor.dart';
import 'package:test/test.dart';
import 'package:socks5_proxy/enums.dart';
import 'package:socks5_proxy/exceptions.dart';
import 'package:bull_tor/src/data/tor_connection_failure_classifier.dart';

void main() {
  test('classifies SOCKS command replies without exposing the destination', () {
    expect(
      classifySocksConnectionFailure(
        const SocksClientConnectionCommandFailedException(
          CommandReplyCode.networkUnreachable,
        ),
      ),
      SocksConnectionFailureCause.tor,
    );
    expect(
      classifySocksConnectionFailure(
        const SocksClientConnectionCommandFailedException(
          CommandReplyCode.hostUnreachable,
        ),
      ),
      SocksConnectionFailureCause.onionServiceUnreachable,
    );
    expect(
      classifySocksConnectionFailure(
        const SocksClientConnectionCommandFailedException(
          CommandReplyCode.connectionRefused,
        ),
      ),
      SocksConnectionFailureCause.serviceRefused,
    );
    expect(
      classifySocksConnectionFailure(
        const SocksClientConnectionCommandFailedException(
          CommandReplyCode.ttlExpired,
        ),
      ),
      SocksConnectionFailureCause.connectionBudgetExceeded,
    );
    expect(
      classifySocksConnectionFailure(
        const SocksClientConnectionCommandFailedException(
          CommandReplyCode.serverError,
        ),
      ),
      SocksConnectionFailureCause.unknown,
    );
    expect(
      classifySocksConnectionFailure(StateError('unrecognised')),
      SocksConnectionFailureCause.unknown,
    );
  });

  test('cause labels are short, stable, and destination-free', () {
    for (final cause in SocksConnectionFailureCause.values) {
      expect(cause.logValue.length, lessThan(32));
      expect(cause.logValue, matches(RegExp(r'^[a-z_]+$')));
    }
  });
}
