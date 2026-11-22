import 'dart:convert';

import 'package:bbx_api/bbx_api.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

Map<String, Object?> _page(List<Object?> elements) => {
  'result': {'elements': elements},
};

void main() {
  group('listMessages', () {
    test('asks api-commcenter for a page, newest first', () async {
      final http = FakeHttp(body: _page([]));
      valueOf(await bbx(http).commcenter.listMessages(page: 2, pageSize: 5));

      final request = http.requests.single;
      expect(request.path, '/ak/api-commcenter');
      expect(
        jsonEncode(request.data),
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":'
        '{"sortBy":{"id":"createdAt","sort":"desc"},'
        '"paginator":{"page":2,"pageSize":5}}}',
      );
    });

    test('defaults to the first page of ten', () async {
      final http = FakeHttp(body: _page([]));
      valueOf(await bbx(http).commcenter.listMessages());

      final request = http.requests.single;
      expect((request.data as Map)['params']['paginator'], {
        'page': 1,
        'pageSize': 10,
      });
    });

    test('reads the messages and their attachments', () async {
      final messages = valueOf(
        await bbx(
          FakeHttp(
            body: _page([
              {
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
                    'fileData': [4, 5],
                  },
                  {'attachmentId': 'a-3', 'fileData': 'AQID'},
                  {
                    'attachmentId': 'a-4',
                    'fileData': {'data': null},
                  },
                ],
              },
              {'messageId': 'm-2'},
            ]),
          ),
        ).commcenter.listMessages(),
      );

      final [first, second] = messages;
      expect(first.messageId, 'm-1');
      expect(first.text, 'Hello');
      expect(first.fromUserId, 'u-1');
      expect(first.toGroupCode, 'support');
      expect(first.createdAt, DateTime.utc(2026, 11, 20, 10));
      expect(first.updatedAt, isNull);
      final attachments =
          first.attachments ?? fail('Expected message attachments');
      final [a1, a2, a3, a4] = attachments;
      expect(a1.attachmentId, 'a-1');
      expect(a1.fileName, 'a.png');
      expect(a1.fileType, 'image/png');
      expect(a1.fileSize, 3);
      expect(a1.fileData, [1, 2, 3]);
      expect(a1.messageId, isNull);
      expect(a1.createdAt, DateTime.utc(2026, 11, 20, 10));
      expect(a2.fileData, [4, 5]);
      expect(a3.fileData, isNull, reason: 'base64 is not read in a list');
      expect(a4.fileData, isNull);
      expect(second.attachments, isNull);
    });

    test('a missing element list is empty', () async {
      final messages = valueOf(
        await bbx(FakeHttp(body: {'result': <String, Object?>{}})).commcenter
            .listMessages(),
      );
      expect(messages, isEmpty);
    });

    for (final body in [
      {'result': null},
      _page(['not an object']),
      _page([
        {'createdAt': 1},
      ]),
      _page([
        {
          'attachments': ['not an object'],
        },
      ]),
      _page([
        {
          'attachments': [
            {
              'fileData': ['x'],
            },
          ],
        },
      ]),
      _page([
        {
          'attachments': [
            {
              'fileData': {'data': 'x'},
            },
          ],
        },
      ]),
      _page([
        {
          'attachments': [
            {'fileSize': 1.5},
          ],
        },
      ]),
    ]) {
      test('$body is a format error', () async {
        expect(
          await failedCall(bbx(FakeHttp(body: body)).commcenter.listMessages()),
          isA<BbxResponseFormatFailure>(),
        );
      });
    }
  });

  group('sendMessageToSupport', () {
    test('sends the text, source and base64 attachments', () async {
      final http = FakeHttp(body: {'result': null});
      valueOf(
        await bbx(http).commcenter.sendMessageToSupport(
          text: 'Hi',
          source: 'BULL Mobile',
          attachments: const [
            NewSupportAttachment(
              fileName: 'a.png',
              fileType: 'image/png',
              fileSize: 3,
              fileData: [1, 2, 3],
            ),
            NewSupportAttachment(fileData: []),
          ],
        ),
      );

      final request = http.requests.single;
      expect(request.path, '/ak/api-commcenter');
      expect(
        jsonEncode(request.data),
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":'
        '{"element":{"text":"Hi","source":"BULL Mobile","attachments":['
        '{"fileName":"a.png","fileType":"image/png","fileSize":3,'
        '"fileData":"AQID"},'
        '{"fileName":null,"fileType":null,"fileSize":null,"fileData":""}]}}}',
      );
    });

    test('sends null attachments as null', () async {
      final http = FakeHttp(body: {'result': null});
      valueOf(
        await bbx(http).commcenter
            .sendMessageToSupport(text: 'Hi', source: 'BULL Mobile'),
      );

      final request = http.requests.single;
      expect(
        jsonEncode((request.data as Map)['params']),
        '{"element":{"text":"Hi","source":"BULL Mobile","attachments":null}}',
      );
    });

    test('a JSON-RPC error is a failure', () async {
      final http = FakeHttp(
        body: {
          'error': {'code': 1},
        },
      );

      expect(
        await failedCall(
          bbx(http).commcenter.sendMessageToSupport(text: 'Hi', source: 's'),
        ),
        isA<BbxRpcFailure>(),
      );
    });
  });

  group('getMessageAttachment', () {
    test('asks for the attachment by id', () async {
      final http = FakeHttp(
        body: {
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
      );
      final attachment = valueOf(
        await bbx(http).commcenter.getMessageAttachment('a-1'),
      );

      final request = http.requests.single;
      expect(request.path, '/ak/api-commcenter');
      expect(
        jsonEncode(request.data),
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment",'
        '"params":{"attachmentId":"a-1"}}',
      );
      expect(attachment.attachmentId, 'a-1');
      expect(attachment.fileName, 'a.pdf');
      expect(attachment.fileType, 'application/pdf');
      expect(attachment.fileSize, 3);
      expect(attachment.fileData, [1, 2, 3]);
      expect(attachment.messageId, 'm-1');
      expect(attachment.createdAt, DateTime.utc(2026, 11, 20, 10));
    });

    for (final (fileData, bytes) in [
      (
        {
          'data': [1, 2],
        },
        [1, 2],
      ),
      ([3], [3]),
      (null, null),
      ({'data': null}, null),
      (7, null),
    ]) {
      test('reads fileData $fileData as $bytes', () async {
        final attachment = valueOf(
          await bbx(
            FakeHttp(
              body: {
                'result': {'fileData': fileData},
              },
            ),
          ).commcenter.getMessageAttachment('a'),
        );
        expect(attachment.fileData, bytes);
      });
    }

    for (final body in [
      {'result': null},
      {'result': 'x'},
      {
        'result': {'fileData': 'not base64!'},
      },
    ]) {
      test('$body is a format error', () async {
        expect(
          await failedCall(
            bbx(FakeHttp(body: body)).commcenter.getMessageAttachment('a'),
          ),
          isA<BbxResponseFormatFailure>(),
        );
      });
    }
  });
}
