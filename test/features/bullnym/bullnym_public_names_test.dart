import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:test/test.dart';

void main() {
  group('BullnymPublicName', () {
    test('accepts the exact shared server syntax', () {
      for (final value in [
        'a',
        '0',
        'alice',
        'alice-shop',
        'a1-b2',
        'a' * 32,
      ]) {
        expect(BullnymPublicName(value).value, value, reason: value);
      }
    });

    test('rejects non-canonical or out-of-range values', () {
      for (final value in [
        '',
        'Alice',
        ' alice',
        'alice ',
        '-alice',
        'alice-',
        'alice_shop',
        'alice.shop',
        'café',
        'alice\n',
        'a' * 33,
      ]) {
        expect(
          () => BullnymPublicName(value),
          throwsArgumentError,
          reason: value,
        );
      }
    });

    test('claim factories mirror the exact server reservation sets', () {
      for (final value in bullnymReservedNyms) {
        expect(
          () => BullnymPublicName.nymClaim(value),
          throwsArgumentError,
          reason: value,
        );
      }
      for (final value in bullnymReservedAliases) {
        expect(
          () => BullnymPublicName.aliasClaim(value),
          throwsArgumentError,
          reason: value,
        );
      }

      expect(BullnymPublicName.nymClaim('coffee').value, 'coffee');
      expect(BullnymPublicName.aliasClaim('coffee').value, 'coffee');
    });
  });

  group('permanent-name protocol values', () {
    test('alias intent exposes only preserve and valid non-empty claim', () {
      const preserve = BullnymAliasIntent.preserve();
      final claim = BullnymAliasIntent.claim(
        BullnymPublicName.aliasClaim('coffee'),
      );

      expect(preserve, isA<BullnymAliasPreserve>());
      expect((claim as BullnymAliasClaim).alias, BullnymPublicName('coffee'));
      expect(() => BullnymPublicName.aliasClaim(''), throwsArgumentError);
      expect(
        () => BullnymAliasIntent.claim(BullnymPublicName('bullpay')),
        throwsArgumentError,
      );
    });

    test('quota must be non-negative and internally consistent', () {
      final quota = BullnymQuota(used: 1, cap: 1, remaining: 0);
      expect(quota.used, 1);
      expect(quota.cap, 1);
      expect(quota.remaining, 0);

      for (final values in [
        (used: -1, cap: 1, remaining: 2),
        (used: 2, cap: 1, remaining: -1),
        (used: 0, cap: -1, remaining: -1),
        (used: 0, cap: 1, remaining: 0),
      ]) {
        expect(
          () => BullnymQuota(
            used: values.used,
            cap: values.cap,
            remaining: values.remaining,
          ),
          throwsArgumentError,
        );
      }
    });

    test('capability enables only the exact permanent_names_v1 policy', () {
      expect(
        const BullnymVersionInfo(
          publicNamePolicy: bullnymPermanentNamesV1Policy,
        ).supportsPermanentNamesV1,
        isTrue,
      );
      expect(
        const BullnymVersionInfo(
          publicNamePolicy: 'permanent_names_v2',
        ).supportsPermanentNamesV1,
        isFalse,
      );
      expect(
        const BullnymVersionInfo(
          publicNamePolicy: null,
        ).supportsPermanentNamesV1,
        isFalse,
      );
    });
  });

  group('BullnymPublicUrl', () {
    final nym = BullnymPublicName('alice');
    final alias = BullnymPublicName('coffee');
    final production = Uri.parse('https://pay2.bull-wallet.com');

    test('accepts canonical nym and alias URLs for both surface kinds', () {
      final cases = [
        (
          value: 'https://pay2.bull-wallet.com/alice',
          alias: null,
          kind: 'payment_page',
        ),
        (
          value: 'https://pay2.bull-wallet.com/alice/pos',
          alias: null,
          kind: 'pos',
        ),
        (
          value: 'https://pay2.bull-wallet.com/a/coffee',
          alias: alias,
          kind: 'payment_page',
        ),
        (
          value: 'https://pay2.bull-wallet.com/a/coffee/pos',
          alias: alias,
          kind: 'pos',
        ),
      ];

      for (final item in cases) {
        expect(
          BullnymPublicUrl.validated(
            value: item.value,
            trustedPublicOrigin: production,
            nym: nym,
            alias: item.alias,
            kind: item.kind,
          ).value,
          item.value,
        );
      }
    });

    test('allows HTTP only for an explicitly trusted local fixture', () {
      expect(
        BullnymPublicUrl.validated(
          value: 'http://localhost:3000/alice',
          trustedPublicOrigin: Uri.parse('http://localhost:3000'),
          nym: nym,
          alias: null,
          kind: 'payment_page',
        ).value,
        'http://localhost:3000/alice',
      );
    });

    test('rejects hostile origins and non-canonical paths', () {
      for (final value in [
        'http://pay2.bull-wallet.com/alice',
        'https://evil.example/alice',
        'https://attacker@pay2.bull-wallet.com/alice',
        'https://pay2.bull-wallet.com/alice?next=evil',
        'https://pay2.bull-wallet.com/alice#fragment',
        'https://pay2.bull-wallet.com/alice/pos',
        'https://pay2.bull-wallet.com/a/coffee',
        'https://pay2.bull-wallet.com/a/alice',
      ]) {
        expect(
          () => BullnymPublicUrl.validated(
            value: value,
            trustedPublicOrigin: production,
            nym: nym,
            alias: null,
            kind: 'payment_page',
          ),
          throwsArgumentError,
          reason: value,
        );
      }
    });
  });
}
