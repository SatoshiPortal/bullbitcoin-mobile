import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/exchange_support_chat_datasource.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
import 'package:bb_mobile/core/exchange/data/http/exchange_authentication_interceptor.dart';
import 'package:bb_mobile/core/exchange/data/repository/exchange_support_chat_repository_impl.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bb_mobile/features/exchange/data/bbx_api_support_chat_repository.dart';
import 'package:bbx_api/bbx_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

/// Answers each JSON-RPC method with its body in [bodies], or throws [error].
class _ChatHttp implements HttpClientAdapter {
  final Map<String, Object?> bodies;
  final DioExceptionType? error;
  final List<(String, String)> sent = [];

  _ChatHttp(this.bodies, {this.error});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add((options.path, jsonEncode(options.data)));
    if (error case final type?) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString(
      jsonEncode(bodies[(options.data as Map)['method']]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _summary = {
  'userNumber': 42,
  'userId': 'u-1',
  'groups': <String>[],
  'profile': {'firstName': 'Satoshi', 'lastName': 'Nakamoto'},
  'email': 'sat@example.com',
  'balances': <Object?>[],
  'dca': {'isActive': false},
  'autoBuy': {'isActive': false, 'addresses': <String, Object?>{}},
};

const _message = {
  'messageId': 'm-1',
  'text': 'Hello',
  'fromUserId': 'u-1',
  'toGroupCode': 'support',
  'createdAt': '2026-11-20T10:00:00Z',
  'updatedAt': 'not a date',
  'attachments': [
    null,
    {
      'attachmentId': 'a-1',
      'fileName': 'a.png',
      'fileType': 'image/png',
      'fileSize': 3,
      'fileData': {
        'type': 'Buffer',
        'data': [1, 2, 3],
      },
      'createdAt': '2026-11-20T10:00:00Z',
    },
    {
      'attachmentId': 'a-2',
      'messageId': 'm-other',
      'fileData': [4, 5],
    },
    {'fileName': 'b.pdf', 'fileData': 'AQID'},
    {'fileType': 'image/png', 'fileSize': 1},
  ],
};

const _rpcError = {
  'error': {'code': -32000, 'message': 'rejected'},
};

Dio _dio(HttpClientAdapter http, {ReadExchangeApiKey? readApiKey}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'))
    ..httpClientAdapter = http;
  if (readApiKey != null) addExchangeAuthentication(dio, readApiKey);
  return dio;
}

ExchangeSupportChatRepository _old(
  HttpClientAdapter http, {
  ReadExchangeApiKey? key,
}) {
  final dio = _dio(http, readApiKey: key);
  return ExchangeSupportChatRepositoryImpl(
    datasource: ExchangeSupportChatDatasource(bullbitcoinApiHttpClient: dio),
    bullbitcoinApiDatasource: BullbitcoinApiDatasource(
      bullbitcoinApiHttpClient: dio,
    ),
  );
}

ExchangeSupportChatRepository _new(
  HttpClientAdapter http, {
  ReadExchangeApiKey? key,
}) {
  final api = BbxApiClient(_dio(http, readApiKey: key));
  return BbxApiSupportChatRepository(
    users: api.users,
    commcenter: api.commcenter,
  );
}

Map<String, Object?> _attachment(SupportChatMessageAttachment a) => {
  'attachmentId': a.attachmentId,
  'fileName': a.fileName,
  'fileType': a.fileType,
  'fileSize': a.fileSize,
  'fileData': a.fileData?.toList(),
  'messageId': a.messageId,
  'createdAt': a.createdAt,
};

Object? _value(Object? value) => switch (value) {
  final List<SupportChatMessage> messages => [
    for (final m in messages)
      {
        'messageId': m.messageId,
        'text': m.text,
        'fromUserId': m.fromUserId,
        'toGroupCode': m.toGroupCode,
        'createdAt': m.createdAt,
        'updatedAt': m.updatedAt,
        'isAdmin': m.isAdmin,
        'attachments': m.attachments?.map(_attachment).toList(),
      },
  ],
  final SupportChatMessageAttachment a => _attachment(a),
  _ => value,
};

/// The value of an [Ok], or the failure type of an [Err].
Object? _outcome(Result<Object?, ExchangeSupportChatFailure> result) =>
    switch (result) {
      Ok(:final value) => ['ok', _value(value)],
      Err(:final failure) => failure.runtimeType,
    };

typedef _Call = Future<Result<Object?, ExchangeSupportChatFailure>> Function(
  ExchangeSupportChatRepository,
);

/// Runs [call] on the old and the new repository against the same answers.
Future<((List<(String, String)>, Object?), (List<(String, String)>, Object?))>
_both(
  _Call call,
  Map<String, Object?> bodies, {
  DioExceptionType? error,
  ReadExchangeApiKey? key,
}) async {
  final oldHttp = _ChatHttp(bodies, error: error);
  final newHttp = _ChatHttp(bodies, error: error);
  final oldOutcome = _outcome(await call(_old(oldHttp, key: key)));
  final newOutcome = _outcome(await call(_new(newHttp, key: key)));
  return ((oldHttp.sent, oldOutcome), (newHttp.sent, newOutcome));
}

final _calls = <String, _Call>{
  'getMessages': (r) => r.getMessages(),
  'sendMessage': (r) => r.sendMessage(text: 'Hi'),
  'getMessageAttachment': (r) => r.getMessageAttachment('a-1'),
};

void main() {
  group('getMessages matches the old repository', () {
    final cases = <String, Map<String, Object?>>{
      'a page': {
        'getUserSummary': {'result': _summary},
        'listMessages': {
          'result': {
            'elements': [
              _message,
              {'messageId': 'm-2', 'fromUserId': 'staff'},
            ],
          },
        },
      },
      'no elements': {
        'getUserSummary': {'result': _summary},
        'listMessages': {'result': <String, Object?>{}},
      },
      'no result': {
        'getUserSummary': {'result': _summary},
        'listMessages': {'result': null},
      },
      'a list error': {
        'getUserSummary': {'result': _summary},
        'listMessages': _rpcError,
      },
      'an unreadable message': {
        'getUserSummary': {'result': _summary},
        'listMessages': {
          'result': {
            'elements': [
              {'createdAt': 1},
            ],
          },
        },
      },
      'an unreadable attachment': {
        'getUserSummary': {'result': _summary},
        'listMessages': {
          'result': {
            'elements': [
              {
                'attachments': [
                  {
                    'fileData': {'data': 'x'},
                  },
                ],
              },
            ],
          },
        },
      },
      'no user id': {
        'getUserSummary': {
          'result': {..._summary, 'userId': null},
        },
      },
      'no summary': {
        'getUserSummary': {'result': null},
      },
      'a summary error': {'getUserSummary': _rpcError},
      'an unreadable summary': {
        'getUserSummary': {
          'result': {'userId': 'u-1'},
        },
      },
    };
    for (final MapEntry(key: name, value: bodies) in cases.entries) {
      for (final (page, pageSize) in [(null, null), (3, 25)]) {
        test('$name, page $page of $pageSize', () async {
          final ((oldSent, oldOutcome), (sent, outcome)) = await _both(
            (r) => r.getMessages(page: page, pageSize: pageSize),
            bodies,
          );

          expect(outcome, oldOutcome);
          expect(sent.length, oldSent.length);
          expect(sent.first.$1, oldSent.first.$1);
          expect(sent.skip(1), oldSent.skip(1));
        });
      }
    }

    test('reads the messages and sends the page', () async {
      final ((_, oldOutcome), (sent, outcome)) = await _both(
        (r) => r.getMessages(page: 3, pageSize: 25),
        cases['a page']!,
      );

      expect(outcome, oldOutcome);
      final messages = (outcome! as List<Object?>)[1]! as List<Object?>;
      final first = messages[0]! as Map<String, Object?>;
      final second = messages[1]! as Map<String, Object?>;
      expect(first['isAdmin'], isFalse);
      expect(second['isAdmin'], isTrue);
      expect(
        [
          for (final a in first['attachments']! as List<Map<String, Object?>>)
            [a['attachmentId'], a['messageId'], a['fileData']],
        ],
        [
          [
            'a-1',
            'm-1',
            [1, 2, 3],
          ],
          [
            'a-2',
            'm-other',
            [4, 5],
          ],
          [null, 'm-1', null],
        ],
      );
      expect(sent.last, (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":'
            '{"sortBy":{"id":"createdAt","sort":"desc"},'
            '"paginator":{"page":3,"pageSize":25}}}',
      ));
    });

    test('asks for the summary with request id "0" instead of 1', () async {
      final ((oldSent, _), (sent, _)) = await _both(
        (r) => r.getMessages(),
        cases['a page']!,
      );

      expect(
        oldSent.first.$2,
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      );
      expect(
        sent.first.$2,
        '{"jsonrpc":"2.0","id":"0","method":"getUserSummary","params":{}}',
      );
      expect(sent.first.$1, '/ak/api-users');
    });
  });

  group('sendMessage matches the old repository', () {
    final attachments = <String, List<SupportChatMessageAttachment>?>{
      'no attachments': null,
      'an empty list': [],
      'attachments': [
        SupportChatMessageAttachment(
          attachmentId: 'local',
          fileName: 'a.png',
          fileType: 'image/png',
          fileSize: 3,
          fileData: Uint8List.fromList([1, 2, 3]),
          messageId: 'm',
          createdAt: DateTime.utc(2026),
        ),
        const SupportChatMessageAttachment(fileName: 'no data'),
        SupportChatMessageAttachment(fileData: Uint8List(0)),
      ],
    };
    for (final MapEntry(key: name, value: list) in attachments.entries) {
      for (final (label, body) in [
        ('accepted', <String, Object?>{'result': null}),
        ('rejected', _rpcError),
        ('not an object', 'OK'),
      ]) {
        test('$name, $label', () async {
          final ((oldSent, oldOutcome), (sent, outcome)) = await _both(
            (r) => r.sendMessage(text: 'Hi', attachments: list),
            {'sendMessageToSupport': body},
          );

          expect(sent, oldSent);
          expect(outcome, oldOutcome);
        });
      }
    }

    test('sends the attachments with file data, base64', () async {
      final ((_, _), (sent, _)) = await _both(
        (r) =>
            r.sendMessage(text: 'Hi', attachments: attachments['attachments']),
        {
          'sendMessageToSupport': {'result': null},
        },
      );

      expect(sent.single, (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":'
            '{"element":{"text":"Hi","source":"BULL Mobile","attachments":['
            '{"fileName":"a.png","fileType":"image/png","fileSize":3,'
            '"fileData":"AQID"},'
            '{"fileName":null,"fileType":null,"fileSize":null,'
            '"fileData":""}]}}}',
      ));
    });
  });

  group('getMessageAttachment matches the old repository', () {
    final results = <String, Object?>{
      'a base64 file': {
        'result': {
          'attachmentId': 'a-1',
          'fileName': 'a.pdf',
          'fileType': 'application/pdf',
          'fileSize': 3,
          'fileData': 'AQID',
          'messageId': 'm-1',
          'createdAt': '2026-11-20T10:00:00Z',
        },
      },
      'a buffer': {
        'result': {
          'fileData': {
            'type': 'Buffer',
            'data': [1, 2],
          },
        },
      },
      'a byte list': {
        'result': {
          'fileData': [3],
        },
      },
      'a null buffer': {
        'result': {
          'fileData': {'data': null},
        },
      },
      'a number': {
        'result': {'fileData': 7},
      },
      'no file data': {'result': <String, Object?>{}},
      'invalid base64': {
        'result': {'fileData': 'not base64!'},
      },
      'no result': {'result': null},
      'a result that is not an object': {'result': 'x'},
      'an error': _rpcError,
    };
    for (final MapEntry(key: name, value: body) in results.entries) {
      test(name, () async {
        final ((oldSent, oldOutcome), (sent, outcome)) = await _both(
          (r) => r.getMessageAttachment('a-1'),
          {'getMessageAttachment': body},
        );

        expect(sent, oldSent);
        expect(outcome, oldOutcome);
      });
    }
  });

  group('auth and transport failures match the old repository', () {
    final bodies = {
      'getUserSummary': {'result': _summary},
      'listMessages': {
        'result': {'elements': <Object?>[]},
      },
    };
    for (final MapEntry(key: name, value: call) in _calls.entries) {
      test('$name signed out is not authenticated', () async {
        final ((oldSent, oldOutcome), (sent, outcome)) = await _both(
          call,
          bodies,
          key: () async => const Ok(null),
        );

        expect(outcome, NotAuthenticatedFailure);
        expect(outcome, oldOutcome);
        expect(sent, isEmpty);
        expect(oldSent, isEmpty);
      });

      test('$name with an unreadable key keeps its failure', () async {
        final ((_, oldOutcome), (_, outcome)) = await _both(
          call,
          bodies,
          key: () async => const Err(ExchangeApiKeyReadFailure()),
        );

        expect(outcome, isNot(NotAuthenticatedFailure));
        expect(outcome, oldOutcome);
      });

      test('$name on a timeout keeps its failure', () async {
        final ((_, oldOutcome), (_, outcome)) = await _both(
          call,
          bodies,
          error: DioExceptionType.connectionTimeout,
        );

        expect(outcome, isNot(NotAuthenticatedFailure));
        expect(outcome, oldOutcome);
      });
    }
  });
}
