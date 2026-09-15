import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr/nostr.dart' as nostr;
import 'package:web_socket_channel/web_socket_channel.dart';

class _Channel extends Mock implements WebSocketChannel {}

class _Sink extends Mock implements WebSocketSink {}

void main() {
  final keys = nostr.Keys('0' * 63 + '1');
  final tags = <List<String>>[
    ['d', 'portable-backup'],
    ['t', 'age'],
  ];
  final event = nostr.Event.from(
    kind: 1090,
    content: 'encrypted',
    secretKey: keys.secret,
    createdAt: 1,
    tags: tags,
    verify: true,
  );

  final relay = Uri.parse('wss://relay.example');
  late _Channel channel;
  late _Sink sink;
  late StreamController<dynamic> incoming;
  late List<List<dynamic>> sent;
  late NostrRelayDatasource datasource;

  setUp(() {
    channel = _Channel();
    sink = _Sink();
    incoming = StreamController<dynamic>();
    sent = [];
    when(() => channel.ready).thenAnswer((_) async {});
    when(() => channel.stream).thenAnswer((_) => incoming.stream);
    when(() => channel.sink).thenReturn(sink);
    when(() => sink.add(any())).thenAnswer((call) {
      sent.add(jsonDecode(call.positionalArguments.first as String) as List);
    });
    when(() => sink.close()).thenAnswer((_) async {
      unawaited(incoming.close());
    });
    datasource = NostrRelayDatasource(
      connect: (_) => channel,
      timeout: const Duration(milliseconds: 100),
    );
  });

  Future<String> subscription() async {
    await Future<void>.delayed(Duration.zero);
    return sent.first[1] as String;
  }

  test('refuses relays that are not plain wss origins', () {
    for (final bad in [
      'ws://relay.example',
      'wss://user@relay.example',
      'wss://relay.example/?q=1',
      'wss://relay.example/#f',
      'https://relay.example',
    ]) {
      expect(
        () => NostrRelayDatasource.validateRelay(Uri.parse(bad)),
        throwsFormatException,
        reason: bad,
      );
    }
    NostrRelayDatasource.validateRelay(Uri.parse('wss://relay.example/path'));
  });

  test(
    'the REQ is the library filter with this transport\'s event limit',
    () async {
      final future = datasource.fetch(
        nostr.Filter(
          authors: [keys.public],
          kinds: const [1090],
          tagFilters: const {
            'd': ['portable-backup'],
          },
          limit: 999,
        ),
        relay,
        NostrSession(),
      );
      final id = await subscription();
      expect(sent.first[0], 'REQ');
      expect(sent.first[2], {
        'authors': [keys.public],
        'kinds': [1090],
        '#d': ['portable-backup'],
        'limit': NostrRelayDatasource.maxEvents,
      });
      incoming.add(nostr.Eose(id).serialize());
      expect((await future).incomplete, isFalse);
      expect(sent.last, ['CLOSE', id]);
    },
  );

  test('events come back as library events, shape-checked only', () async {
    final future = datasource.fetch(
      const nostr.Filter(),
      relay,
      NostrSession(),
    );
    final id = await subscription();
    // A well-formed frame whose signature is wrong is still handed over: the
    // caller verifies against its own profile. A frame that is not an event
    // at all is dropped and makes the result incomplete.
    final forged = {...event.toMap(), 'sig': '0' * 128};
    incoming.add(jsonEncode(['EVENT', id, event.toMap()]));
    incoming.add(jsonEncode(['EVENT', id, forged]));
    incoming.add(nostr.Eose(id).serialize());
    final result = await future;
    expect(result.events.map((item) => item.toMap()), [event.toMap(), forged]);
    expect(result.events.first.isValid(), isTrue);
    expect(result.events.last.isValid(), isFalse);
    expect(result.incomplete, isFalse);
  });

  test('transport failure preserves received events as incomplete', () async {
    final future = datasource.fetch(
      const nostr.Filter(),
      relay,
      NostrSession(),
    );
    final id = await subscription();
    incoming.add(jsonEncode(['EVENT', id, event.toMap()]));
    incoming.addError(const FormatException('Connection failed'));
    final result = await future;
    expect(result.events.single.toMap(), event.toMap());
    expect(result.incomplete, isTrue);
    expect(sent.last, ['CLOSE', id]);
  });

  test('cancellation preserves candidates and closes the connection', () async {
    final session = NostrSession();
    final future = datasource.fetch(const nostr.Filter(), relay, session);
    final id = await subscription();
    incoming.add(jsonEncode(['EVENT', id, event.toMap()]));
    await Future<void>.delayed(Duration.zero);
    session.cancel();
    final result = await future;
    expect(result.events.single.toMap(), event.toMap());
    expect(result.incomplete, isTrue);
    verify(() => sink.close()).called(1);
  });

  test(
    'discarding malformed or oversized frames makes EOSE incomplete',
    () async {
      final future = datasource.fetch(
        const nostr.Filter(),
        relay,
        NostrSession(),
      );
      final id = await subscription();
      incoming.add('x' * (NostrRelayDatasource.maxFrameBytes + 1));
      incoming.add('{broken');
      incoming.add(
        jsonEncode([
          'EVENT',
          id,
          {'id': 'not an event'},
        ]),
      );
      incoming.add(jsonEncode(['EVENT', id, event.toMap()]));
      incoming.add(nostr.Eose(id).serialize());
      final result = await future;
      expect(result.events.single.toMap(), event.toMap());
      expect(result.incomplete, isTrue);
    },
  );

  test(
    'a relay that says there is more leaves the search incomplete',
    () async {
      final future = datasource.fetch(
        const nostr.Filter(),
        relay,
        NostrSession(),
      );
      final id = await subscription();
      incoming.add(
        jsonEncode([
          'EOSE',
          id,
          ['more'],
        ]),
      );
      expect((await future).incomplete, isTrue);
    },
  );

  test('invalid frame flood terminates without waiting for timeout', () async {
    final future = datasource.fetch(
      const nostr.Filter(),
      relay,
      NostrSession(),
    );
    await subscription();
    for (var i = 0; i < 129; i++) {
      incoming.add('invalid');
    }
    final result = await future;
    expect(result.events, isEmpty);
    expect(result.incomplete, isTrue);
    verify(() => sink.close()).called(1);
  });

  test('publication only completes on a matching accepted event ID', () async {
    final future = datasource.publish(event, relay, NostrSession());
    await Future<void>.delayed(Duration.zero);
    incoming.add(
      const nostr.CommandResult('unrelated', false, 'blocked:').serialize(),
    );
    incoming.add(nostr.CommandResult(event.id, true, '').serialize());
    await future;
    expect(sent.single, ['EVENT', event.toMap()]);
  });

  test('a relay refusal is reported apart from transport failure', () async {
    final future = datasource.publish(event, relay, NostrSession());
    await Future<void>.delayed(Duration.zero);
    incoming.add(
      nostr.CommandResult(event.id, false, 'blocked: no').serialize(),
    );
    await expectLater(future, throwsA(isA<NostrRelayRejectedException>()));
  });
}
