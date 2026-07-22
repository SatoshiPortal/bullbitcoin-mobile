import 'dart:io';
import 'dart:typed_data';

import 'package:coldcard_firmware/coldcard_firmware.dart';
import 'package:coldcard_firmware/src/firmware/downloader.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late String baseUrl;
  late Map<String, List<int>> files;

  setUp(() async {
    files = {};
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    server.listen((request) {
      final body = files[request.uri.path];
      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.contentLength = body.length;
        request.response.add(body);
      }
      request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  FirmwareRelease releaseFor(String filename, {String sha256Hex = ''}) {
    return FirmwareRelease(
      model: ColdcardModel.mk4,
      version: const FirmwareVersion(5, 5, 1),
      timestampRaw: '2026-07-01T1729',
      filename: filename,
      downloadUrl: '$baseUrl/downloads/$filename',
      expectedSha256Hex: sha256Hex,
    );
  }

  test('downloads bytes and reports progress', () async {
    final payload = Uint8List.fromList(
      List.generate(300000, (i) => (i * 31) % 256),
    );
    files['/downloads/fw.dfu'] = payload;

    final progress = <int>[];
    int? reportedTotal;
    final downloader = FirmwareDownloader(dio: Dio());
    final bytes = await downloader.download(
      releaseFor('fw.dfu'),
      onProgress: (received, total) {
        progress.add(received);
        reportedTotal = total;
      },
    );

    expect(bytes, payload);
    expect(progress, isNotEmpty);
    expect(progress.last, payload.length);
    expect(reportedTotal, payload.length);
  });

  test('rejects downloads over the size cap mid-stream', () async {
    // No trustworthy content-length: serve chunked so the cap must trip while streaming.
    final bigServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => bigServer.close(force: true));
    bigServer.listen((request) async {
      final chunk = List.filled(64 * 1024, 0xAB);
      for (var i = 0; i < 40; i++) {
        request.response.add(chunk); // 2.5 MB total
      }
      await request.response.close();
    });

    final downloader = FirmwareDownloader(dio: Dio(), maxBytes: 1024 * 1024);
    final release = FirmwareRelease(
      model: ColdcardModel.mk4,
      version: const FirmwareVersion(5, 5, 1),
      timestampRaw: '2026-07-01T1729',
      filename: 'big.dfu',
      downloadUrl: 'http://127.0.0.1:${bigServer.port}/big.dfu',
      expectedSha256Hex: '',
    );
    expect(
      () => downloader.download(release),
      throwsA(isA<FirmwareTooLargeException>()),
    );
  });

  test('rejects oversized content-length before downloading', () async {
    files['/downloads/huge.dfu'] = List.filled(2048, 0);
    final downloader = FirmwareDownloader(dio: Dio(), maxBytes: 1024);
    expect(
      () => downloader.download(releaseFor('huge.dfu')),
      throwsA(isA<FirmwareTooLargeException>()),
    );
  });

  test('maps HTTP errors to FirmwareNetworkException', () async {
    final downloader = FirmwareDownloader(dio: Dio());
    expect(
      () => downloader.download(releaseFor('missing.dfu')),
      throwsA(isA<FirmwareNetworkException>()),
    );
  });
}
