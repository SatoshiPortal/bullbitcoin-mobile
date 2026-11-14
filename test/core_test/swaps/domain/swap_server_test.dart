import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty input is the network default', () {
    expect(SwapServer.parse('  ', isTestnet: false), SwapServer.mainnetDefault);
    expect(SwapServer.parse('', isTestnet: true), SwapServer.testnetDefault);
    expect(SwapServer.mainnetDefault, isNot(SwapServer.testnetDefault));
  });

  test('strips https and websocket schemes and trailing slashes', () {
    for (final input in [
      'https://boltz.example.com/v2/',
      'wss://boltz.example.com/v2',
      'ws://boltz.example.com/v2',
      ' boltz.example.com/v2 ',
    ]) {
      expect(
        SwapServer.parse(input, isTestnet: false)?.host,
        'boltz.example.com/v2',
      );
    }
  });

  test('accepts ip:port, localhost and onion hosts', () {
    expect(
      SwapServer.parse('10.0.2.2:9001/v2', isTestnet: true)?.host,
      '10.0.2.2:9001/v2',
    );
    expect(
      SwapServer.parse('localhost:9001', isTestnet: true)?.host,
      'localhost:9001',
    );
    expect(
      SwapServer.parse(
        'boltzzzbnus4m7mta3cxmflnps4fp7dueu2tgurstbvrbt6xswzcocyd.onion/api/v2',
        isTestnet: false,
      ),
      isNotNull,
    );
  });

  test('rejects input that is not an address', () {
    expect(SwapServer.parse('not a host', isTestnet: false), isNull);
    expect(SwapServer.parse('https://', isTestnet: false), isNull);
  });

  test('keeps an explicit http scheme, but only on testnet', () {
    final server = SwapServer.parse('http://10.0.2.2:9001/v2', isTestnet: true);

    expect(server?.isPlaintext, isTrue);
    expect(
      server?.forEnvironment(isTestnet: true).host,
      'http://10.0.2.2:9001/v2',
    );
    expect(server?.forEnvironment(isTestnet: false).host, '10.0.2.2:9001/v2');
  });

  test('the defaults never carry a scheme', () {
    for (final server in [
      SwapServer.mainnetDefault,
      SwapServer.testnetDefault,
    ]) {
      expect(server.isPlaintext, isFalse);
      expect(server.host.contains('://'), isFalse);
    }
  });
}
