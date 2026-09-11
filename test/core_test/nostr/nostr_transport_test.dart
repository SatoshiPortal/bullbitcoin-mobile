import 'dart:async';
import 'dart:convert';

import 'package:bb_mobile/core/nostr/nostr_event.dart';
import 'package:bb_mobile/core/nostr/nostr_relay_datasource.dart';
import 'package:bb_mobile/core/nostr/nostr_session.dart';
import 'package:bitcoin_base/bitcoin_base.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Channel extends Mock implements WebSocketChannel {}

class _Sink extends Mock implements WebSocketSink {}

void main() {
  final key = ECPrivate.fromHex('0' * 63 + '1');
  final author = hex.encode(key.getPublic().toXOnly());
  final tags = <List<String>>[
    ['d', 'portable-backup'],
    ['t', 'age'],
  ];
  final digest = NostrEvent.hash(
    author: author,
    createdAt: 1,
    kind: 1090,
    tags: tags,
    content: 'encrypted',
  );
  final event = NostrEvent(
    id: digest,
    author: author,
    createdAt: 1,
    kind: 1090,
    tags: tags,
    content: 'encrypted',
    signature: key.signBip340(hex.decode(digest), tweak: false),
  );

  test('generic event verifies its exact author, kind, tags and payload', () {
    expect(NostrEvent.parse(event.toJson()).toJson(), event.toJson());
    for (final change in <Map<String, dynamic>>[
      {'content': 'changed'},
      {'kind': 1089},
      {'created_at': 2},
      {'sig': '0' * 128},
      {
        'tags': [
          ['t', 'age'],
          ['d', 'portable-backup'],
        ],
      },
    ]) {
      expect(
        () => NostrEvent.parse({...event.toJson(), ...change}),
        throwsFormatException,
      );
    }
    expect(
      () => NostrEvent.parse(event.toJson(), maxContentBytes: 3),
      throwsFormatException,
    );
    final invalidAuthor = 'f' * 64;
    expect(
      () => NostrEvent.parse({
        ...event.toJson(),
        'pubkey': invalidAuthor,
        'id': NostrEvent.hash(
          author: invalidAuthor,
          createdAt: event.createdAt,
          kind: event.kind,
          tags: event.tags,
          content: event.content,
        ),
      }),
      throwsFormatException,
    );
  });

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

  test(
    'filter preserves author/kind/tags and enforces the event limit',
    () async {
      final future = datasource.fetch(
        {
          'authors': [author],
          'kinds': [1090],
          '#d': ['portable-backup'],
          'limit': 999,
        },
        relay,
        NostrSession(),
      );
      final id = await subscription();
      expect(sent.first[2], {
        'authors': [author],
        'kinds': [1090],
        '#d': ['portable-backup'],
        'limit': 32,
      });
      incoming.add(jsonEncode(['EOSE', id]));
      expect((await future).incomplete, isFalse);
      expect(sent.last, ['CLOSE', id]);
    },
  );

  test('transport failure preserves received events as incomplete', () async {
    final future = datasource.fetch({}, relay, NostrSession());
    final id = await subscription();
    incoming.add(jsonEncode(['EVENT', id, event.toJson()]));
    incoming.addError(const FormatException('Connection failed'));
    final result = await future;
    expect(result.events.single, event.toJson());
    expect(result.incomplete, isTrue);
    expect(sent.last, ['CLOSE', id]);
  });

  test('cancellation preserves candidates and closes the connection', () async {
    final session = NostrSession();
    final future = datasource.fetch({}, relay, session);
    final id = await subscription();
    incoming.add(jsonEncode(['EVENT', id, event.toJson()]));
    await Future<void>.delayed(Duration.zero);
    session.cancel();
    final result = await future;
    expect(result.events.single, event.toJson());
    expect(result.incomplete, isTrue);
    verify(() => sink.close()).called(1);
  });

  test(
    'discarding malformed or oversized frames makes EOSE incomplete',
    () async {
      final future = datasource.fetch({}, relay, NostrSession());
      final id = await subscription();
      incoming.add('x' * (NostrRelayDatasource.maxFrameBytes + 1));
      incoming.add('{broken');
      incoming.add(jsonEncode(['EVENT', id, event.toJson()]));
      incoming.add(jsonEncode(['EOSE', id]));
      final result = await future;
      expect(result.events.single, event.toJson());
      expect(result.incomplete, isTrue);
    },
  );

  test('invalid frame flood terminates without waiting for timeout', () async {
    final future = datasource.fetch({}, relay, NostrSession());
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
    incoming.add(jsonEncode(['OK', 'unrelated', false]));
    incoming.add(jsonEncode(['OK', event.id, true]));
    await future;
    expect(sent.single, ['EVENT', event.toJson()]);
  });
}
