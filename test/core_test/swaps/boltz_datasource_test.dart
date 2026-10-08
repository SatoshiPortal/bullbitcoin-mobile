import 'package:bb_mobile/core/swaps/data/datasources/boltz_datasource.dart';
import 'package:bb_mobile/core/swaps/data/datasources/boltz_storage_datasource.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_sdk/boltz.dart' show SkippedRestoreSwap;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBoltzStorageDatasource extends Mock
    implements BoltzStorageDatasource {}

class _RecordingLogSink implements LogSink {
  final List<(String, String)> entries = [];

  @override
  void fine(String message, {Object? error, StackTrace? trace}) =>
      entries.add(('fine', message));

  @override
  void info(String message, {Object? error, StackTrace? trace}) =>
      entries.add(('info', message));

  @override
  void warning(String message, {Object? error, StackTrace? trace}) =>
      entries.add(('warning', message));

  @override
  void error(String message, {Object? error, StackTrace? trace}) =>
      entries.add(('error', message));

  @override
  LogSink scoped(String scope) => this;
}

void main() {
  test('does not open a websocket when constructed', () {
    var webSocketCreations = 0;

    BoltzDatasource(
      boltzStore: _MockBoltzStorageDatasource(),
      webSocketFactory:
          (
            String _, {
            void Function()? onDone,
            void Function(Object error)? onError,
          }) {
            webSocketCreations++;
            throw StateError('Websocket should stay lazy');
          },
    );

    expect(webSocketCreations, 0);
  });

  group('logSkippedBoltzRestores', () {
    test('logs nothing when the restore skipped no swap', () {
      final sink = _RecordingLogSink();

      logSkippedBoltzRestores(sink, kind: 'ln_btc', skipped: const []);

      expect(sink.entries, isEmpty);
    });

    test('warns with the kind and count only, never the swap id or error', () {
      final sink = _RecordingLogSink();

      logSkippedBoltzRestores(
        sink,
        kind: 'chain',
        skipped: const [
          SkippedRestoreSwap(id: 'swapIdOne', error: 'preimage not derived'),
          SkippedRestoreSwap(id: 'swapIdTwo', error: 'preimage not derived'),
        ],
      );

      expect(sink.entries, [
        ('warning', 'boltz.restore.skipped kind=chain count=2'),
      ]);
    });
  });
}
