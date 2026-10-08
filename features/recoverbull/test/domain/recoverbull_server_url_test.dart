import 'package:bull_recoverbull/src/domain/recoverbull_server_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final onion = '${'a' * 56}.onion';

  group('validateRecoverBullServerUrl', () {
    final accepted = <String, ({String url, bool allowLoopback})>{
      'onion host': (url: 'http://$onion', allowLoopback: false),
      'onion host with port 80': (
        url: 'http://$onion:80',
        allowLoopback: false,
      ),
      'onion host with max port': (
        url: 'http://$onion:65535',
        allowLoopback: false,
      ),
      'onion host with path': (url: 'http://$onion/v1', allowLoopback: false),
      'uppercase onion host': (
        url: 'http://${onion.toUpperCase()}',
        allowLoopback: false,
      ),
      'ipv4 loopback when allowed': (
        url: 'http://127.0.0.1',
        allowLoopback: true,
      ),
      'ipv4 loopback with port when allowed': (
        url: 'http://127.0.0.1:8080',
        allowLoopback: true,
      ),
      'localhost when allowed': (
        url: 'http://localhost:3000',
        allowLoopback: true,
      ),
      'ipv6 loopback when allowed': (
        url: 'http://[::1]:3000',
        allowLoopback: true,
      ),
    };
    for (final entry in accepted.entries) {
      test('accepts ${entry.key}', () {
        final url = Uri.parse(entry.value.url);
        expect(
          validateRecoverBullServerUrl(
            url,
            allowLoopback: entry.value.allowLoopback,
          ),
          url,
        );
      });
    }

    final rejected = <String, ({String url, bool allowLoopback})>{
      'https onion': (url: 'https://$onion', allowLoopback: false),
      'https loopback': (url: 'https://127.0.0.1', allowLoopback: true),
      'user info': (url: 'http://user@$onion', allowLoopback: false),
      'user and password': (url: 'http://user:pw@$onion', allowLoopback: false),
      'query': (url: 'http://$onion?x=1', allowLoopback: false),
      'empty query marker': (url: 'http://$onion?', allowLoopback: false),
      'fragment': (url: 'http://$onion#frag', allowLoopback: false),
      'localhost without allowLoopback': (
        url: 'http://localhost',
        allowLoopback: false,
      ),
      '127.0.0.1 without allowLoopback': (
        url: 'http://127.0.0.1',
        allowLoopback: false,
      ),
      'ipv6 loopback without allowLoopback': (
        url: 'http://[::1]',
        allowLoopback: false,
      ),
      'clearnet host': (url: 'http://example.com', allowLoopback: false),
      'clearnet host with allowLoopback': (
        url: 'http://example.com',
        allowLoopback: true,
      ),
      'onion lookalike suffix': (
        url: 'http://$onion.example.com',
        allowLoopback: true,
      ),
      'empty host': (url: 'http://', allowLoopback: false),
      'empty host with allowLoopback': (url: 'http://', allowLoopback: true),
      'port zero': (url: 'http://$onion:0', allowLoopback: false),
      'port above range': (url: 'http://$onion:65536', allowLoopback: false),
      'no scheme': (url: onion, allowLoopback: false),
      'other scheme': (url: 'ftp://$onion', allowLoopback: false),
    };
    for (final entry in rejected.entries) {
      test('rejects ${entry.key}', () {
        expect(
          () => validateRecoverBullServerUrl(
            Uri.parse(entry.value.url),
            allowLoopback: entry.value.allowLoopback,
          ),
          throwsArgumentError,
        );
      });
    }
  });
}
