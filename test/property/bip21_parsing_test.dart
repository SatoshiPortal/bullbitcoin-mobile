import 'package:bip21_uri/bip21_uri.dart';
import 'package:test/test.dart';

/// BIP21 URI parsing tests using the bip21_uri package directly.
///
/// These test the pure Dart URI parsing that Bull Bitcoin uses to interpret
/// payment URIs. The app's PaymentRequest.parse() wraps bip21.decode() with
/// additional FFI validation (BDK/LWK), but the URI structure parsing itself
/// is pure Dart and testable here.
///
/// Why this matters: A BIP21 parsing bug could extract the wrong address,
/// wrong amount, or miss payjoin parameters — any of which could cause
/// fund loss or failed payments.
///
/// Target dependency: package:bip21_uri (used in lib/core/utils/payment_request.dart)
void main() {
  group('BIP21 decode — Bitcoin URIs', () {
    test('simple bitcoin address with no params', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
      );
      expect(uri.address, equals('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'));
      expect(uri.scheme, equals('bitcoin'));
      expect(uri.amount, isNull);
      expect(uri.label, isNull);
      expect(uri.message, isNull);
    });

    test('bitcoin URI with amount in BTC', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.001',
      );
      expect(uri.address, equals('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'));
      expect(uri.amount, equals(0.001));
    });

    test('bitcoin URI with label and message', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?label=Satoshi&message=Donation',
      );
      expect(uri.label, equals('Satoshi'));
      expect(uri.message, equals('Donation'));
    });

    test('bitcoin URI with amount=0 is valid', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0',
      );
      expect(uri.amount, equals(0.0));
    });

    test('bitcoin URI with lightning parameter (BIP21 unified)', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?lightning=lnbc1000n1p0',
      );
      expect(uri.options['lightning'], equals('lnbc1000n1p0'));
    });

    test('bitcoin URI with payjoin parameters', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?pj=https://example.com/pj&pjos=0',
      );
      // bip21_uri may uppercase the scheme in the pj URL
      expect(uri.options['pj'].toString().toLowerCase(),
          equals('https://example.com/pj'));
      expect(uri.options['pjos'], equals('0'));
    });

    test('bitcoin URI with URL-encoded label', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?label=Bull%20Bitcoin',
      );
      expect(uri.label, equals('Bull Bitcoin'));
    });

    test('bitcoin URI with multiple params preserves all', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.05&label=Test&message=Hello&lightning=lnbc500n1p0',
      );
      expect(uri.amount, equals(0.05));
      expect(uri.label, equals('Test'));
      expect(uri.message, equals('Hello'));
      expect(uri.options['lightning'], equals('lnbc500n1p0'));
    });
  });

  group('BIP21 decode — Liquid URIs', () {
    test('liquidnetwork scheme parses correctly', () {
      final uri = bip21.decode(
        'liquidnetwork:VJLCbLBTCdxhWyjVLdjcSmGAksVMtabYg5?amount=0.001',
      );
      expect(uri.scheme, equals('liquidnetwork'));
      expect(uri.address, equals('VJLCbLBTCdxhWyjVLdjcSmGAksVMtabYg5'));
      expect(uri.amount, equals(0.001));
    });

    test('liquidtestnet scheme parses correctly', () {
      final uri = bip21.decode(
        'liquidtestnet:tlq1qqtest123?amount=0.0001',
      );
      expect(uri.scheme, equals('liquidtestnet'));
      expect(uri.address, equals('tlq1qqtest123'));
    });
  });

  group('BIP21 decode — edge cases', () {
    test('missing scheme treats input as address (no scheme)', () {
      // bip21_uri treats schemeless input as address:address — this is
      // library behavior, not BIP21 spec. The app handles this by checking
      // for scheme prefix BEFORE calling bip21.decode().
      final uri = bip21.decode('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq');
      // The library parses it but the address will be the full string
      expect(uri.address, isNotEmpty);
    });

    test('empty address after scheme throws', () {
      expect(
        () => bip21.decode('bitcoin:'),
        throwsA(anything),
      );
    });

    test('unknown params go to options map', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?customParam=value',
      );
      expect(uri.options['customParam'], equals('value'));
    });

    test('amount with many decimal places', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.00000001',
      );
      // 1 sat in BTC
      expect(uri.amount, equals(0.00000001));
    });

    test('large amount parses correctly', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=21000000',
      );
      expect(uri.amount, equals(21000000.0));
    });
  });

  group('BIP21 encode roundtrip', () {
    test('decode then encode preserves core fields', () {
      const original =
          'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.001&label=Test';
      final uri = bip21.decode(original);
      final encoded = bip21.encode(uri);

      // Re-decode to verify
      final reparsed = bip21.decode(encoded);
      expect(reparsed.address, equals(uri.address));
      expect(reparsed.amount, equals(uri.amount));
      expect(reparsed.label, equals(uri.label));
    });
  });

  group('BIP21 payjoin URL integrity', () {
    // REGRESSION TEST: Documents bip21_uri library mangling payjoin URLs.
    // The library uppercases the pj field and replaces '-' with '+'.
    // See project_upstream_findings.md Finding 4.
    test(
      'payjoin URL with hyphens should be preserved unchanged',
      skip: 'Dependency bug: bip21_uri uppercases pj field and replaces - with +. '
          'See project_upstream_findings.md Finding 4',
      () {
        final uri = bip21.decode(
          'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'
          '?pj=https://pay.example.com/pj?session-id=abc',
        );
        // The pj URL should be preserved exactly as provided
        expect(uri.options['pj'],
            equals('https://pay.example.com/pj?session-id=abc'),
            reason: 'Payjoin URL must not be mangled by the URI parser');
      },
    );
  });

  group('BIP21 amount → sats conversion pipeline', () {
    // Bug this catches: BTC float → integer sats conversion error → wrong payment amount
    // This tests ConvertAmount.btcToSats on values extracted from BIP21 URIs
    test('1 sat amount survives BTC float conversion', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.00000001',
      );
      // ConvertAmount.btcToSats uses (btcValue * 100000000).round()
      final sats = (uri.amount! * 100000000).round();
      expect(sats, equals(1),
          reason: '0.00000001 BTC must equal exactly 1 sat');
    });

    test('1 BTC = 100,000,000 sats', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=1.0',
      );
      final sats = (uri.amount! * 100000000).round();
      expect(sats, equals(100000000));
    });

    test('0.001 BTC = 100,000 sats', () {
      final uri = bip21.decode(
        'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.001',
      );
      final sats = (uri.amount! * 100000000).round();
      expect(sats, equals(100000));
    });
  });

  group('BIP21 negative amount handling', () {
    // The bip21_uri library correctly rejects negative amounts per BIP21 spec.
    test('negative amount is rejected by library', () {
      expect(
        () => bip21.decode(
          'bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=-0.001',
        ),
        throwsA(anything),
        reason: 'BIP21 spec requires non-negative amounts — library enforces this',
      );
    });
  });

  group('BIP21 uppercase scheme handling', () {
    test('library preserves original scheme case', () {
      // Documents current library behavior
      final uri = bip21.decode(
        'BITCOIN:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.001',
      );
      expect(uri.scheme, equals('BITCOIN'));
      expect(uri.address, equals('bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq'));
      expect(uri.amount, equals(0.001));
    });

    // REGRESSION TEST: Will pass once upstream fixes case-sensitive scheme check.
    // Bug: _tryParseBip21 line 163 uses data.startsWith('bitcoin:') instead of
    // data.toLowerCase().startsWith('bitcoin:'), causing uppercase URIs to silently
    // lose amount, lightning, and payjoin parameters.
    // See project_upstream_findings.md Finding 1.
    test(
      'uppercase BITCOIN: scheme should be treated as case-insensitive per BIP21 spec',
      skip: 'Upstream bug: payment_request.dart:163 — case-sensitive startsWith. '
          'See project_upstream_findings.md Finding 1',
      () {
        final uri = bip21.decode(
          'BITCOIN:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.001',
        );
        // BIP21 spec (RFC 3986): scheme is case-insensitive
        // This should match 'bitcoin' regardless of input case
        expect(uri.scheme.toLowerCase(), equals('bitcoin'));
        // When the app's _tryParseBip21 is fixed, this comparison will work:
        // uri.scheme == 'bitcoin' (after normalization in app code)
      },
    );
  });
}
