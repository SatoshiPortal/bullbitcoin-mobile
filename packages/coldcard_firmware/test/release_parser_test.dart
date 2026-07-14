import 'package:coldcard_firmware/coldcard_firmware.dart';
import 'package:coldcard_firmware/src/firmware/release_parser.dart';
import 'package:test/test.dart';

void main() {
  group('ParsedFirmwareFilename.tryParse', () {
    test('parses a current Mk4-line filename (-mk- since v5.5.0)', () {
      final p = ParsedFirmwareFilename.tryParse(
        '2026-07-01T1729-v5.5.1-mk-coldcard.dfu',
      )!;
      expect(p.timestampRaw, '2026-07-01T1729');
      expect(p.version, const FirmwareVersion(5, 5, 1));
      expect(p.modelSuffix, 'mk');
      expect(p.isEdge, isFalse);
      expect(p.isFactory, isFalse);
    });

    test('parses a historical -mk4- filename', () {
      final p = ParsedFirmwareFilename.tryParse(
        '2025-11-03T1525-v5.4.5-mk4-coldcard.dfu',
      )!;
      expect(p.modelSuffix, 'mk4');
      expect(p.version, const FirmwareVersion(5, 4, 5));
    });

    test('parses a -mk3- filename', () {
      final p = ParsedFirmwareFilename.tryParse(
        '2022-10-05T1517-v5.0.3-mk3-coldcard.dfu',
      )!;
      expect(p.modelSuffix, 'mk3');
    });

    test('parses a Q filename with Q version marker', () {
      final p = ParsedFirmwareFilename.tryParse(
        '2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu',
      )!;
      expect(p.modelSuffix, 'q1');
      expect(p.version, const FirmwareVersion(1, 4, 1, hasQMarker: true));
    });

    test('parses a legacy filename with no model suffix', () {
      final p = ParsedFirmwareFilename.tryParse(
        '2022-05-27T1046-v4.1.9-coldcard.dfu',
      )!;
      expect(p.modelSuffix, isNull);
      expect(p.version, const FirmwareVersion(4, 1, 9));
    });

    test('flags edge builds (X marker), including on the -mk- suffix', () {
      expect(
        ParsedFirmwareFilename.tryParse(
          '2025-04-01T0000-v6.4.1X-mk4-coldcard.dfu',
        )!.isEdge,
        isTrue,
      );
      expect(
        ParsedFirmwareFilename.tryParse(
          '2026-05-01T0000-v6.5.0X-mk-coldcard.dfu',
        )!.isEdge,
        isTrue,
      );
    });

    test('flags a hypothetical QX edge build', () {
      final p = ParsedFirmwareFilename.tryParse(
        '2026-05-01T0000-v6.5.0QX-q1-coldcard.dfu',
      )!;
      expect(p.isEdge, isTrue);
      expect(p.version.hasQMarker, isTrue);
    });

    test('flags -factory images', () {
      final p = ParsedFirmwareFilename.tryParse(
        '2026-07-01T1727-v1.4.1Q-q1-coldcard-factory.dfu',
      )!;
      expect(p.isFactory, isTrue);
    });

    test(
      'returns null (never throws) on hostile oversized version numbers',
      () {
        final huge = '9' * 100;
        expect(
          ParsedFirmwareFilename.tryParse(
            '2026-07-01T1729-v$huge.5.1-mk-coldcard.dfu',
          ),
          isNull,
        );
        expect(
          ParsedFirmwareFilename.tryParse(
            '2026-07-01T1729-v5.$huge.1-mk-coldcard.dfu',
          ),
          isNull,
        );
        expect(
          ParsedFirmwareFilename.tryParse(
            '2026-07-01T1729-v5.5.$huge-mk-coldcard.dfu',
          ),
          isNull,
        );
      },
    );

    test('rejects non-firmware names', () {
      for (final name in [
        'README.md',
        '2024-05-09T1527-v1.2.1Q-q1-coldcard.md',
        'v5.5.1-mk-coldcard.dfu', // no timestamp
        '2026-07-01T1729-5.5.1-mk-coldcard.dfu', // no v
        '2026-07-01T1729-v5.5.1-mk5-coldcard.dfu', // unknown suffix
        'evil-2026-07-01T1729-v5.5.1-mk-coldcard.dfu', // prefix junk
        '2026-07-01T1729-v5.5.1-mk-coldcard.dfu.exe', // trailing junk
      ]) {
        expect(ParsedFirmwareFilename.tryParse(name), isNull, reason: name);
      }
    });
  });

  group('isOfferedFor', () {
    ParsedFirmwareFilename parse(String name) =>
        ParsedFirmwareFilename.tryParse(name)!;

    test('Q accepts only q1 files with the Q marker', () {
      final q = parse('2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu');
      expect(q.isOfferedFor(ColdcardModel.q), isTrue);
      expect(q.isOfferedFor(ColdcardModel.mk4), isFalse);
    });

    test('Mk4 accepts both -mk- and -mk4- files', () {
      expect(
        parse(
          '2026-07-01T1729-v5.5.1-mk-coldcard.dfu',
        ).isOfferedFor(ColdcardModel.mk4),
        isTrue,
      );
      expect(
        parse(
          '2025-11-03T1525-v5.4.5-mk4-coldcard.dfu',
        ).isOfferedFor(ColdcardModel.mk4),
        isTrue,
      );
    });

    test('Mk4 rejects mk3, legacy, edge and factory files', () {
      for (final name in [
        '2022-10-05T1517-v5.0.3-mk3-coldcard.dfu',
        '2022-05-27T1046-v4.1.9-coldcard.dfu',
        '2026-05-01T0000-v6.5.0X-mk-coldcard.dfu',
        '2026-07-01T1729-v5.5.1-mk-coldcard-factory.dfu',
      ]) {
        expect(
          parse(name).isOfferedFor(ColdcardModel.mk4),
          isFalse,
          reason: name,
        );
      }
    });

    test('a q1-suffixed file without Q marker is rejected for Q', () {
      // Defensive: has never been published, but the two flags must agree.
      final weird = parse('2026-07-01T1727-v1.4.1-q1-coldcard.dfu');
      expect(weird.isOfferedFor(ColdcardModel.q), isFalse);
    });
  });

  group('FirmwareVersion', () {
    test('orders by major.minor.patch', () {
      const a = FirmwareVersion(5, 4, 5);
      const b = FirmwareVersion(5, 5, 0);
      const c = FirmwareVersion(5, 5, 1);
      expect(a.compareTo(b), lessThan(0));
      expect(c.compareTo(b), greaterThan(0));
      expect([c, a, b]..sort(), [a, b, c]);
    });

    test('renders with Q marker', () {
      expect(
        const FirmwareVersion(1, 4, 1, hasQMarker: true).toString(),
        'v1.4.1Q',
      );
      expect(const FirmwareVersion(5, 5, 1).toString(), 'v5.5.1');
    });
  });

  group('FirmwareRelease.releasedAt', () {
    FirmwareRelease release(String timestampRaw) {
      return FirmwareRelease(
        model: ColdcardModel.mk4,
        version: const FirmwareVersion(5, 5, 1),
        timestampRaw: timestampRaw,
        filename: '$timestampRaw-v5.5.1-mk-coldcard.dfu',
        downloadUrl: 'https://example.com/firmware.dfu',
        expectedSha256Hex: '0' * 64,
      );
    }

    test('preserves the filename timestamp components in UTC', () {
      final releasedAt = release('2026-07-01T1729').releasedAt;

      expect(releasedAt, isNotNull);
      expect(releasedAt!.isUtc, isTrue);
      expect(
        [
          releasedAt.year,
          releasedAt.month,
          releasedAt.day,
          releasedAt.hour,
          releasedAt.minute,
        ],
        [2026, 7, 1, 17, 29],
      );
    });

    test('does not normalize a timestamp that is a local DST gap', () {
      expect(
        release('2026-03-08T0230').releasedAt,
        DateTime.utc(2026, 3, 8, 2, 30),
      );
    });

    test('returns null for malformed or invalid timestamps', () {
      for (final timestamp in [
        '',
        '2026-07-01T17:29',
        '2026-13-01T1729',
        '2026-02-30T1729',
        '2026-07-01T2460',
      ]) {
        expect(release(timestamp).releasedAt, isNull, reason: timestamp);
      }
    });
  });
}
