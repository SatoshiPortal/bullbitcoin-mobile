import 'package:bull_payjoin/src/engine/payjoin_constants.dart';
import 'package:bull_payjoin/src/engine/payjoin_servers.dart';
import 'package:test/test.dart';

void main() {
  final bull = Uri.https('pj.bullbitcoin.com');
  final bobspace = Uri.https('pj.bobspacebkk.com');
  final vinteum = Uri.https('payjoin.lab.vinteum.org');
  final planB = Uri.https('pj.pow.plan-b.foundation');
  final servers = PayjoinConstants.serverUrls;

  const address = 'bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4';
  String uriWith(String pj) => 'bitcoin:$address?amount=0.001&pj=$pj';

  // BIP77 writes the pj endpoint in uppercase, fragment included.
  const vinteumUri =
      'bitcoin:BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4?amount=0.001'
      '&pj=HTTPS://PAYJOIN.LAB.VINTEUM.ORG/ABCDEF%23RK1QXYZ-OH1QXYZ-EX1ABC';

  final refuses = throwsA(isA<PayjoinRelayUnavailableException>());

  test('every server is on its own domain', () {
    expect(servers, [bull, bobspace, vinteum, planB]);
    expect(servers.map(payjoinDomainOf), [
      'bullbitcoin.com',
      'bobspacebkk.com',
      'vinteum.org',
      'plan-b.foundation',
    ]);
  });

  test('allows every server except the directory of the URI', () {
    expect(allowedRelays(uriWith('$bobspace/abc'), servers: servers), [
      bull,
      vinteum,
      planB,
    ]);
  });

  test('reads the directory of an uppercase BIP77 URI', () {
    expect(payjoinDirectoryOf(vinteumUri)?.host, 'payjoin.lab.vinteum.org');
    expect(allowedRelays(vinteumUri, servers: servers), [
      bull,
      bobspace,
      planB,
    ]);
  });

  test('a different spelling of the directory is still its domain', () {
    for (final pj in [
      'HTTPS://PJ.BULLBITCOIN.COM/ABC',
      'https://pj.bullbitcoin.com./abc',
      'https://pj.bullbitcoin.com:8443/abc',
      'https://pj%2Ebullbitcoin.com/abc',
      'https://payjoin.bullbitcoin.com/abc',
      'https://bullbitcoin.com/abc',
    ]) {
      expect(allowedRelays(uriWith(pj), servers: servers), [
        bobspace,
        vinteum,
        planB,
      ], reason: pj);
    }
  });

  test('a relay on the directory domain is the same entity', () {
    final sameEntity = Uri.https('ohttp.example.com');
    final otherEntity = Uri.https('ohttp.example.org');
    final pool = [sameEntity, otherEntity];
    expect(relaysOutsideDomainOf(Uri.https('dir.example.com'), servers: pool), [
      otherEntity,
    ]);
    expect(
      allowedRelays(uriWith('https://dir.example.com/abc'), servers: pool),
      [otherEntity],
    );
  });

  test('allows every server for a directory outside their domains', () {
    expect(
      allowedRelays(uriWith('https://payjo.in/abc'), servers: servers),
      servers,
    );
  });

  test('reaches a directory before any URI exists through other domains', () {
    expect(relaysOutsideDomainOf(planB, servers: servers), [
      bull,
      bobspace,
      vinteum,
    ]);
  });

  test('an IP address is its own domain', () {
    expect(payjoinDomainOf(Uri.parse('https://10.0.0.1:8080')), '10.0.0.1');
    expect(payjoinDomainOf(Uri.parse('https://[::1]/x')), '::1');
  });

  group('refuses rather than risk the same domain', () {
    test('when the URI carries no pj endpoint', () {
      expect(
        () => allowedRelays('bitcoin:$address', servers: servers),
        refuses,
      );
    });

    test('when the pj endpoint carries credentials', () {
      expect(
        () => allowedRelays(
          uriWith('https://user@pj.bobspacebkk.com/a'),
          servers: servers,
        ),
        refuses,
      );
    });

    test('when the pj endpoint is not a URL', () {
      expect(
        () => allowedRelays(uriWith('not-a-url'), servers: servers),
        refuses,
      );
    });

    test('when the URI is not a valid BIP21 URI', () {
      expect(
        () => allowedRelays('bitcoin:?pj=$bobspace/abc', servers: servers),
        refuses,
      );
    });

    test('when the directory host has an empty label', () {
      expect(
        () => relaysOutsideDomainOf(
          Uri.parse('https://pj..bull.com'),
          servers: servers,
        ),
        refuses,
      );
    });

    test('when the directory host is not ASCII', () {
      expect(
        () => relaysOutsideDomainOf(
          Uri.parse('https://büllbitcoin.com'),
          servers: servers,
        ),
        refuses,
      );
    });

    test('when the only server is on the directory domain', () {
      expect(() => allowedRelays(vinteumUri, servers: [vinteum]), refuses);
    });
  });
}
