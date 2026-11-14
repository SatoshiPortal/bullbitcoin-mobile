import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

String? sqliteTimingSkipReason = 'SQLite timing bootstrap did not run';

// Flutter's sampling SIGPROF interrupts SQLite busy-handler sleeps on Linux.
Future<void> configureSqliteTestTiming() async {
  const timeout = Duration(seconds: 5);
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final info = await developer.Service.getInfo().timeout(timeout);
    final uri = info.serverUri;
    if (uri == null) throw StateError('VM service unavailable');
    Future<Map<String, dynamic>> rpc(
      String method, [
      Map<String, String> parameters = const {},
    ]) async {
      final request = await client.getUrl(
        uri.resolve(method).replace(queryParameters: parameters),
      );
      final response = await request.close();
      final body =
          jsonDecode(await utf8.decoder.bind(response).join())
              as Map<String, dynamic>;
      final result = body['result'];
      if (result is! Map<String, dynamic>) {
        throw StateError('VM service $method failed');
      }
      return result;
    }

    await rpc('setFlag', {
      'name': 'profiler',
      'value': 'false',
    }).timeout(timeout);
    final result = await rpc('getFlagList').timeout(timeout);
    final flags = result['flags'] as List<dynamic>;
    if (!flags.any(
      (dynamic flag) =>
          flag['name'] == 'profiler' && flag['valueAsString'] == 'false',
    )) {
      throw StateError('VM profiler is still enabled');
    }
    sqliteTimingSkipReason = null;
  } on Object catch (error) {
    sqliteTimingSkipReason =
        'Real SQLite busy waits require the VM profiler disabled '
        '(bootstrap failed: ${error is StateError ? error.message : error.runtimeType}); '
        'try --enable-vmservice';
    // Only timing-dependent tests use this skip reason; other tests still run.
    stderr.writeln(sqliteTimingSkipReason);
  } finally {
    client.close(force: true);
  }
}
