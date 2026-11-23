import 'package:exchange/exchange.dart';

typedef NotAuthenticatedFailure = ExchangeNotAuthenticatedFailure;
typedef LoadMessagesFailure = ExchangeChatLoadMessagesFailure;
typedef SendMessageFailure = ExchangeChatSendMessageFailure;
typedef LoadAttachmentFailure = ExchangeChatLoadAttachmentFailure;

/// What the removed ExchangeSupportChatRepositoryImpl sent and gave for each
/// case of `bbx_api_support_chat_repository_test.dart`: the requests, and the
/// value or failure type.
final oldRepository = <String, Object?>{
  'a page, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":1,"pageSize":10}}}',
      ),
    ],
    [
      'ok',
      [
        {
          'messageId': 'm-1',
          'text': 'Hello',
          'fromUserId': 'u-1',
          'toGroupCode': 'support',
          'createdAt': DateTime.parse('2026-11-20T10:00:00.000Z'),
          'updatedAt': null,
          'isAdmin': false,
          'attachments': [
            {
              'attachmentId': 'a-1',
              'fileName': 'a.png',
              'fileType': 'image/png',
              'fileSize': 3,
              'fileData': [1, 2, 3],
              'messageId': 'm-1',
              'createdAt': DateTime.parse('2026-11-20T10:00:00.000Z'),
            },
            {
              'attachmentId': 'a-2',
              'fileName': null,
              'fileType': null,
              'fileSize': null,
              'fileData': [4, 5],
              'messageId': 'm-other',
              'createdAt': null,
            },
            {
              'attachmentId': null,
              'fileName': 'b.pdf',
              'fileType': null,
              'fileSize': null,
              'fileData': null,
              'messageId': 'm-1',
              'createdAt': null,
            },
          ],
        },
        {
          'messageId': 'm-2',
          'text': null,
          'fromUserId': 'staff',
          'toGroupCode': null,
          'createdAt': null,
          'updatedAt': null,
          'isAdmin': true,
          'attachments': null,
        },
      ],
    ],
  ),
  'a page, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":3,"pageSize":25}}}',
      ),
    ],
    [
      'ok',
      [
        {
          'messageId': 'm-1',
          'text': 'Hello',
          'fromUserId': 'u-1',
          'toGroupCode': 'support',
          'createdAt': DateTime.parse('2026-11-20T10:00:00.000Z'),
          'updatedAt': null,
          'isAdmin': false,
          'attachments': [
            {
              'attachmentId': 'a-1',
              'fileName': 'a.png',
              'fileType': 'image/png',
              'fileSize': 3,
              'fileData': [1, 2, 3],
              'messageId': 'm-1',
              'createdAt': DateTime.parse('2026-11-20T10:00:00.000Z'),
            },
            {
              'attachmentId': 'a-2',
              'fileName': null,
              'fileType': null,
              'fileSize': null,
              'fileData': [4, 5],
              'messageId': 'm-other',
              'createdAt': null,
            },
            {
              'attachmentId': null,
              'fileName': 'b.pdf',
              'fileType': null,
              'fileSize': null,
              'fileData': null,
              'messageId': 'm-1',
              'createdAt': null,
            },
          ],
        },
        {
          'messageId': 'm-2',
          'text': null,
          'fromUserId': 'staff',
          'toGroupCode': null,
          'createdAt': null,
          'updatedAt': null,
          'isAdmin': true,
          'attachments': null,
        },
      ],
    ],
  ),
  'no elements, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":1,"pageSize":10}}}',
      ),
    ],
    ['ok', []],
  ),
  'no elements, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":3,"pageSize":25}}}',
      ),
    ],
    ['ok', []],
  ),
  'no result, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":1,"pageSize":10}}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'no result, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":3,"pageSize":25}}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'a list error, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":1,"pageSize":10}}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'a list error, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":3,"pageSize":25}}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'an unreadable message, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":1,"pageSize":10}}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'an unreadable message, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":3,"pageSize":25}}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'an unreadable attachment, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":1,"pageSize":10}}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'an unreadable attachment, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"listMessages","params":{"sortBy":{"id":"createdAt","sort":"desc"},"paginator":{"page":3,"pageSize":25}}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'no user id, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    NotAuthenticatedFailure,
  ),
  'no user id, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    NotAuthenticatedFailure,
  ),
  'no summary, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    NotAuthenticatedFailure,
  ),
  'no summary, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    NotAuthenticatedFailure,
  ),
  'a summary error, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    NotAuthenticatedFailure,
  ),
  'a summary error, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    NotAuthenticatedFailure,
  ),
  'an unreadable summary, page null of null': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'an unreadable summary, page 3 of 25': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'no attachments, accepted': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":null}}}',
      ),
    ],
    ['ok', null],
  ),
  'no attachments, rejected': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":null}}}',
      ),
    ],
    SendMessageFailure,
  ),
  'no attachments, not an object': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":null}}}',
      ),
    ],
    SendMessageFailure,
  ),
  'an empty list, accepted': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":[]}}}',
      ),
    ],
    ['ok', null],
  ),
  'an empty list, rejected': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":[]}}}',
      ),
    ],
    SendMessageFailure,
  ),
  'an empty list, not an object': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":[]}}}',
      ),
    ],
    SendMessageFailure,
  ),
  'attachments, accepted': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":[{"fileName":"a.png","fileType":"image/png","fileSize":3,"fileData":"AQID"},{"fileName":null,"fileType":null,"fileSize":null,"fileData":""}]}}}',
      ),
    ],
    ['ok', null],
  ),
  'attachments, rejected': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":[{"fileName":"a.png","fileType":"image/png","fileSize":3,"fileData":"AQID"},{"fileName":null,"fileType":null,"fileSize":null,"fileData":""}]}}}',
      ),
    ],
    SendMessageFailure,
  ),
  'attachments, not an object': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":[{"fileName":"a.png","fileType":"image/png","fileSize":3,"fileData":"AQID"},{"fileName":null,"fileType":null,"fileSize":null,"fileData":""}]}}}',
      ),
    ],
    SendMessageFailure,
  ),
  'attachment: a base64 file': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    [
      'ok',
      {
        'attachmentId': 'a-1',
        'fileName': 'a.pdf',
        'fileType': 'application/pdf',
        'fileSize': 3,
        'fileData': [1, 2, 3],
        'messageId': 'm-1',
        'createdAt': DateTime.parse('2026-11-20T10:00:00.000Z'),
      },
    ],
  ),
  'attachment: a buffer': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    [
      'ok',
      {
        'attachmentId': null,
        'fileName': null,
        'fileType': null,
        'fileSize': null,
        'fileData': [1, 2],
        'messageId': null,
        'createdAt': null,
      },
    ],
  ),
  'attachment: a byte list': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    [
      'ok',
      {
        'attachmentId': null,
        'fileName': null,
        'fileType': null,
        'fileSize': null,
        'fileData': [3],
        'messageId': null,
        'createdAt': null,
      },
    ],
  ),
  'attachment: a null buffer': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    [
      'ok',
      {
        'attachmentId': null,
        'fileName': null,
        'fileType': null,
        'fileSize': null,
        'fileData': null,
        'messageId': null,
        'createdAt': null,
      },
    ],
  ),
  'attachment: a number': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    [
      'ok',
      {
        'attachmentId': null,
        'fileName': null,
        'fileType': null,
        'fileSize': null,
        'fileData': null,
        'messageId': null,
        'createdAt': null,
      },
    ],
  ),
  'attachment: no file data': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    [
      'ok',
      {
        'attachmentId': null,
        'fileName': null,
        'fileType': null,
        'fileSize': null,
        'fileData': null,
        'messageId': null,
        'createdAt': null,
      },
    ],
  ),
  'attachment: invalid base64': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    LoadAttachmentFailure,
  ),
  'attachment: no result': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    LoadAttachmentFailure,
  ),
  'attachment: a result that is not an object': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    LoadAttachmentFailure,
  ),
  'attachment: an error': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    LoadAttachmentFailure,
  ),
  'getMessages signed out': ([], NotAuthenticatedFailure),
  'getMessages with an unreadable key': ([], LoadMessagesFailure),
  'getMessages on a timeout': (
    [
      (
        '/ak/api-users',
        '{"id":1,"jsonrpc":"2.0","method":"getUserSummary","params":{}}',
      ),
    ],
    LoadMessagesFailure,
  ),
  'sendMessage signed out': ([], NotAuthenticatedFailure),
  'sendMessage with an unreadable key': ([], SendMessageFailure),
  'sendMessage on a timeout': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"sendMessageToSupport","params":{"element":{"text":"Hi","source":"BULL Mobile","attachments":null}}}',
      ),
    ],
    SendMessageFailure,
  ),
  'getMessageAttachment signed out': ([], NotAuthenticatedFailure),
  'getMessageAttachment with an unreadable key': ([], LoadAttachmentFailure),
  'getMessageAttachment on a timeout': (
    [
      (
        '/ak/api-commcenter',
        '{"jsonrpc":"2.0","id":"0","method":"getMessageAttachment","params":{"attachmentId":"a-1"}}',
      ),
    ],
    LoadAttachmentFailure,
  ),
};
