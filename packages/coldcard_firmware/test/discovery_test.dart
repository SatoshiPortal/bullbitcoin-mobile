import 'dart:io';

import 'package:coldcard_firmware/coldcard_firmware.dart';
import 'package:coldcard_firmware/src/firmware/discovery.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  final pageQ1 = File('test/fixtures/page_q1.html').readAsStringSync();
  final pageMk = File('test/fixtures/page_mk.html').readAsStringSync();

  group('ReleasePageScraper.extractOffered', () {
    test('finds q1 releases on the Q page, factory variants included', () {
      final offered = ReleasePageScraper.extractOffered(pageQ1);
      expect(offered, isNotEmpty);
      expect(
        offered.map((f) => f.filename),
        contains('2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu'),
      );
    });

    test('finds mk releases on the Mk page', () {
      final offered = ReleasePageScraper.extractOffered(pageMk);
      expect(
        offered.map((f) => f.filename),
        contains('2026-07-01T1729-v5.5.1-mk-coldcard.dfu'),
      );
    });

    test('returns nothing for HTML without firmware links', () {
      expect(ReleasePageScraper.extractOffered('<html></html>'), isEmpty);
    });
  });

  group('ReleasePageScraper.fetchLatestOffered', () {
    late HttpServer server;
    late String baseUrl;
    late Map<String, String> pages;

    setUp(() async {
      pages = {};
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      baseUrl = 'http://127.0.0.1:${server.port}';
      server.listen((request) {
        final body = pages[request.uri.path];
        if (body == null) {
          request.response.statusCode = HttpStatus.notFound;
        } else {
          request.response.write(body);
        }
        request.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('picks the newest non-factory Q release from the real page', () async {
      pages['/downloads/q1'] = pageQ1;
      final scraper = ReleasePageScraper(dio: Dio(), baseUrl: baseUrl);
      final latest = await scraper.fetchLatestOffered(ColdcardModel.q);
      expect(latest.filename, '2026-07-01T1727-v1.4.1Q-q1-coldcard.dfu');
      expect(latest.isFactory, isFalse);
    });

    test('picks the newest Mk4 release from the real page', () async {
      pages['/downloads/mk'] = pageMk;
      final scraper = ReleasePageScraper(dio: Dio(), baseUrl: baseUrl);
      final latest = await scraper.fetchLatestOffered(ColdcardModel.mk4);
      expect(latest.filename, '2026-07-01T1729-v5.5.1-mk-coldcard.dfu');
    });

    test('throws DiscoveryParseException on a page with no releases', () async {
      pages['/downloads/q1'] = '<html>redesigned!</html>';
      final scraper = ReleasePageScraper(dio: Dio(), baseUrl: baseUrl);
      expect(
        () => scraper.fetchLatestOffered(ColdcardModel.q),
        throwsA(isA<DiscoveryParseException>()),
      );
    });

    test('throws FirmwareNetworkException on HTTP failure', () async {
      final scraper = ReleasePageScraper(dio: Dio(), baseUrl: baseUrl);
      expect(
        () => scraper.fetchLatestOffered(ColdcardModel.q), // 404
        throwsA(isA<FirmwareNetworkException>()),
      );
    });
  });
}
