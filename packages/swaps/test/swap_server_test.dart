import 'package:swaps/swaps.dart' show SwapServer, SwapServerCredentials;
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
      SwapServer.parse('localhost:9001/v2', isTestnet: true)?.host,
      'localhost:9001/v2',
    );
    expect(
      SwapServer.parse(
        'boltzzzbnus4m7mta3cxmflnps4fp7dueu2tgurstbvrbt6xswzcocyd.onion/api/v2',
        isTestnet: false,
      ),
      isNotNull,
    );
  });

  test('a bare host gets the /v2 API path', () {
    expect(
      SwapServer.parse('boltz.example.com', isTestnet: false)?.host,
      'boltz.example.com/v2',
    );
    expect(
      SwapServer.parse('http://127.0.0.1:9001', isTestnet: true)?.host,
      'http://127.0.0.1:9001/v2',
    );
  });

  test('a path other than the /v2 API is refused', () {
    expect(SwapServer.parse('boltz.example.com/v1', isTestnet: false), isNull);
    expect(SwapServer.parse('boltz.example.com/api', isTestnet: false), isNull);
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

  test('credentials typed into the address are refused', () {
    expect(
      SwapServer.parse('user:secret@boltz.example.com/v2', isTestnet: false),
      isNull,
    );
    expect(
      SwapServer.parse('https://user@boltz.example.com', isTestnet: false),
      isNull,
    );
  });

  test('two empty fields are no credentials', () {
    expect(SwapServerCredentials.of(username: '', password: ''), isNull);
    expect(
      SwapServerCredentials.of(username: 'user', password: ''),
      const SwapServerCredentials(username: 'user', password: ''),
    );
  });

  test('a username with a colon is not valid for basic authentication', () {
    expect(
      const SwapServerCredentials(username: 'a:b', password: 'x').isValid,
      isFalse,
    );
    expect(
      const SwapServerCredentials(username: 'ab', password: 'x:y').isValid,
      isTrue,
    );
  });

  test('credentials encode as a basic authorization and as user info', () {
    const credentials = SwapServerCredentials(
      username: 'bull',
      password: 'p@ss:w/rd',
    );

    expect(credentials.authorization, 'Basic YnVsbDpwQHNzOncvcmQ=');
    expect(credentials.userInfo, 'bull:p%40ss%3Aw%2Frd');
    expect(credentials.toString(), isNot(contains('p@ss')));
  });

  test('credentials are part of a server and survive the environment', () {
    const credentials = SwapServerCredentials(
      username: 'bull',
      password: 'secret',
    );
    final plain = SwapServer.parse('http://127.0.0.1:9001', isTestnet: true);
    final server = plain?.withCredentials(credentials);

    expect(server, isNot(plain));
    expect(server?.host, plain?.host);
    expect(server.toString(), isNot(contains('secret')));
    expect(server?.forEnvironment(isTestnet: false).credentials, credentials);
    expect(server?.withCredentials(null), plain);
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
