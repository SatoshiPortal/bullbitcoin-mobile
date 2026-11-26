import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One keyless POST. The deadline aborts owned HTTP and awaits its settlement;
/// it never detaches a native future or retries an ambiguous delivery.
final class HttpArkClaimDelivery {
  final Duration deadline;
  const HttpArkClaimDelivery({this.deadline = const Duration(seconds: 15)});

  Future<void> post(Uri source, String raw, String expectedTxid) async {
    final http = HttpClient()..connectionTimeout = deadline;
    HttpClientRequest? pending;
    var expired = false;
    final timer = Timer(deadline, () {
      expired = true;
      pending?.abort(const HttpException('Claim delivery deadline'));
      http.close(force: true);
    });
    try {
      final path = '${source.path.replaceFirst(RegExp(r'/+$'), '')}/tx';
      final request = await http.postUrl(source.replace(path: path));
      pending = request;
      if (expired) {
        request.abort();
        throw const HttpException('Claim delivery deadline');
      }
      request.followRedirects = false;
      request.headers.contentType = ContentType.text;
      request.write(raw);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw const HttpException('Uncertain claim delivery');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        if (bytes.length + chunk.length > 128) {
          request.abort();
          throw const FormatException('Oversize claim reply');
        }
        bytes.addAll(chunk);
      }
      if (expired || ascii.decode(bytes).trim() != expectedTxid) {
        throw const FormatException('Uncertain claim identity');
      }
    } finally {
      timer.cancel();
      http.close(force: true);
    }
  }
}
