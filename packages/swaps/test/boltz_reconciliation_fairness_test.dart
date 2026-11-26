import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;

import 'support/real_swap_backends.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rust_bindings/boltz.dart' as boltz;
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:fake_async/fake_async.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/src/data/boltz_api.dart';
import 'package:swaps/src/data/models/swap_model.dart';
import 'package:swaps/src/data/swap_storage.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:test/test.dart';

class _Rows extends Fake implements SwapRowStore {
  final values = <String, SwapModel>{};
  final fetched = <String>[];
  final stored = <String>[];
  Completer<void>? heldRead;

  _Rows() {
    for (final id in ['a', 'b', 'c', 'd', 'e']) {
      values[id] = SwapModel.lnReceive(
        id: id,
        type: SwapType.lightningToLiquid.name,
        status: SwapStatus.pending.name,
        keyIndex: 0,
        creationTime: DateTime.utc(2026).millisecondsSinceEpoch,
        receiveWalletId: 'public-wallet',
        invoice: 'public-fixture',
      );
    }
  }

  @override
  Future<SwapModel?> fetch(String id) async {
    fetched.add(id);
    await heldRead?.future;
    return values[id];
  }

  @override
  Future<void> store(SwapModel model) async {
    values[model.id] = model;
    stored.add(model.id);
  }
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {
    action(HttpHeaders.contentTypeHeader, ['application/json']);
  }
}

class _Response extends Fake implements HttpClientResponse {
  final String body;
  _Response(this.body);

  Stream<Uint8List> get _bytes =>
      Stream.value(Uint8List.fromList(utf8.encode(body)));

  @override
  int get statusCode => HttpStatus.ok;
  @override
  String get reasonPhrase => 'OK';
  @override
  bool get isRedirect => false;
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpHeaders get headers => _Headers();
  @override
  Stream<R> cast<R>() => _bytes.cast<R>();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _bytes.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

class _Request extends Fake implements HttpClientRequest {
  final _Transport transport;
  final String path;
  final _response = Completer<HttpClientResponse>();
  Timer? _timer;
  _Request(this.transport, this.path);

  @override
  final HttpHeaders headers = _Headers();
  @override
  bool followRedirects = true;
  @override
  int maxRedirects = 5;
  @override
  bool persistentConnection = true;

  @override
  Future<HttpClientResponse> close() {
    _timer = Timer(const Duration(seconds: 11), () {
      if (!_response.isCompleted) {
        final status = path == '/swap/a'
            ? 'swap.created'
            : 'transaction.mempool';
        _response.complete(_Response(jsonEncode({'status': status})));
      }
    });
    return _response.future;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    if (_response.isCompleted) return;
    transport.aborted.add(path);
    _timer?.cancel();
    _response.completeError(
      exception ?? const HttpException('fixture transport cancelled'),
      stackTrace,
    );
  }
}

/// Only the IO transport is controlled. Dio, cancellation, native status
/// parsing, per-swap mutation queue, status mapper and SwapStorage stay real.
class _Client extends Fake implements HttpClient {
  final _Transport transport;
  final active = <_Request>[];
  _Client(this.transport);

  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 3);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async {
    transport.requested.add(uri.path);
    final request = _Request(transport, uri.path);
    active.add(request);
    return request;
  }

  @override
  void close({bool force = false}) {
    if (force) {
      for (final request in active) {
        request.abort();
      }
    }
  }
}

class _Transport {
  final requested = <String>[];
  final aborted = <String>[];
  late final HttpClient client = _Client(this);

  void run(void Function() body) =>
      HttpOverrides.runZoned(body, createHttpClient: (_) => client);
}

BoltzDatasource _datasource(_Rows rows) => BoltzDatasource(
  url: 'http://unused.invalid',
  environment: NetworkEnv.mainnet,
  boltzStore: SwapStorage(
    rows: rows,
    secrets: ReproKeychainBackend().capability,
  ),
  webSocketFactory: (url, {onDone, onError}) =>
      throw StateError('Websocket must stay off'),
);

void _flush(FakeAsync clock) {
  clock.flushMicrotasks();
  clock.elapse(Duration.zero);
  clock.flushMicrotasks();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await BullSdk.init();
    // Native setup failures are not the fairness Red. Check both real parser
    // fixtures before entering any controlled reconciliation pass.
    expect(
      boltz.SwapStatusResponse.fromJson(json: '{"status":"swap.created"}')
          .status,
      boltz.SwapStatus.swapCreated,
    );
    expect(
      boltz.SwapStatusResponse.fromJson(
        json: '{"status":"transaction.mempool"}',
      ).status,
      boltz.SwapStatus.txnMempool,
    );
  });

  test(
    'stable outstanding swaps eventually reconcile d within bounded passes',
    () {
      final transport = _Transport();
      transport.run(
        () => fakeAsync((clock) {
          final rows = _Rows();
          final datasource = _datasource(rows);
          for (var pass = 0; pass < 2; pass++) {
            var done = false;
            unawaited(
              datasource
                  .reconcileSwaps(['a', 'b', 'c', 'd'])
                  .then((_) => done = true),
            );
            _flush(clock);
            clock.elapse(const Duration(seconds: 29));
            expect(done, isFalse);
            clock.elapse(const Duration(seconds: 1));
            _flush(clock);
            expect(
              done,
              isTrue,
              reason: 'HTTP budget remains 30 seconds with responsive writes',
            );
            final stored = rows.stored.toList();
            final fetched = rows.fetched.toList();
            clock.elapse(const Duration(seconds: 20));
            _flush(clock);
            expect(
              rows.stored,
              stored,
              reason: 'No late mutation after the pass drains',
            );
            expect(
              rows.fetched,
              fetched,
              reason: 'Cancelled response cannot enter the event queue',
            );
          }
          expect(transport.requested, contains('/swap/d'));
          expect(rows.values['a']?.status, SwapStatus.pending.name);
          expect(
            rows.values['d']?.status,
            SwapStatus.claimable.name,
            reason: 'Later swap must progress through real parser and mapper',
          );
          expect(transport.aborted, isNotEmpty);
          datasource.dispose();
        }),
      );
    },
  );

  test('overlap joins one owned pass and preserves the interrupted head', () {
    final transport = _Transport();
    transport.run(
      () => fakeAsync((clock) {
        final rows = _Rows();
        final datasource = _datasource(rows);
        var firstDone = false, joinedDone = false;
        final first = datasource.reconcileSwaps(['a', 'b', 'c', 'd', 'd']);
        unawaited(first.then((_) => firstDone = true));
        clock.elapse(const Duration(seconds: 22));
        _flush(clock);
        final joined = datasource.reconcileSwaps([]);
        unawaited(joined.then((_) => joinedDone = true));
        expect(identical(first, joined), isTrue);
        clock.elapse(const Duration(seconds: 7));
        expect(firstDone || joinedDone, isFalse);
        clock.elapse(const Duration(seconds: 1));
        _flush(clock);
        expect(firstDone && joinedDone, isTrue);
        expect(transport.requested, ['/swap/a', '/swap/b', '/swap/c']);
        transport.requested.clear();
        unawaited(datasource.reconcileSwaps(['a', 'b', 'c', 'd']));
        _flush(clock);
        expect(transport.requested, ['/swap/c']);
        clock.elapse(const Duration(seconds: 40));
        datasource.dispose();
      }),
    );
  });

  test(
    'membership removals, newcomers and empty passes preserve waiting order',
    () {
      final transport = _Transport();
      transport.run(
        () => fakeAsync((clock) {
          final datasource = _datasource(_Rows());
          unawaited(datasource.reconcileSwaps(['a', 'b', 'c', 'd']));
          clock.elapse(const Duration(seconds: 30));
          _flush(clock);
          transport.requested.clear();
          unawaited(datasource.reconcileSwaps(['a', 'b', 'd', 'e']));
          _flush(clock);
          expect(transport.requested, ['/swap/d']);
          clock.elapse(const Duration(seconds: 30));
          _flush(clock);
          expect(transport.requested, ['/swap/d', '/swap/a', '/swap/b']);
          unawaited(datasource.reconcileSwaps([]));
          _flush(clock);
          transport.requested.clear();
          unawaited(datasource.reconcileSwaps(['e', 'a']));
          _flush(clock);
          expect(transport.requested, ['/swap/e']);
          clock.elapse(const Duration(seconds: 40));
          datasource.dispose();
        }),
      );
    },
  );

  test('an admitted storage mutation stays owned beyond the HTTP budget', () {
    final transport = _Transport();
    transport.run(
      () => fakeAsync((clock) {
        final release = Completer<void>();
        final rows = _Rows()..heldRead = release;
        final datasource = _datasource(rows);
        var firstDone = false, joinedDone = false;
        final first = datasource.reconcileSwaps(['a', 'b', 'c', 'd']);
        unawaited(first.then((_) => firstDone = true));
        clock.elapse(const Duration(seconds: 11));
        _flush(clock);
        expect(rows.fetched, ['a']);
        final joined = datasource.reconcileSwaps(['e']);
        unawaited(joined.then((_) => joinedDone = true));
        expect(identical(first, joined), isTrue);
        clock.elapse(const Duration(seconds: 40));
        _flush(clock);
        expect(
          firstDone || joinedDone,
          isFalse,
          reason: 'Timer cancels HTTP, not an admitted mutation',
        );
        expect(transport.requested, ['/swap/a']);
        release.complete();
        _flush(clock);
        expect(firstDone && joinedDone, isTrue);
        rows.heldRead = null;
        unawaited(datasource.reconcileSwaps(['a', 'b', 'c', 'd']));
        _flush(clock);
        expect(transport.requested, ['/swap/a', '/swap/b']);
        clock.elapse(const Duration(seconds: 40));
        datasource.dispose();
      }),
    );
  });

  test(
    'close waits for an admitted event and prevents later storage effects',
    () {
      final transport = _Transport();
      transport.run(
        () => fakeAsync((clock) {
          final release = Completer<void>();
          final rows = _Rows()..heldRead = release;
          final datasource = _datasource(rows);
          var drained = false;
          unawaited(datasource.reconcileSwaps(['b', 'c']));
          clock.elapse(const Duration(seconds: 11));
          _flush(clock);
          expect(rows.fetched, ['b']);
          unawaited(datasource.close().then((_) => drained = true));
          clock.elapse(const Duration(seconds: 40));
          _flush(clock);
          expect(drained, isFalse);
          release.complete();
          _flush(clock);
          expect(drained, isTrue);
          expect(rows.stored, isEmpty);
          clock.elapse(const Duration(seconds: 40));
          _flush(clock);
          expect(transport.requested, ['/swap/b']);
          expect(rows.stored, isEmpty);
        }),
      );
    },
  );
}
