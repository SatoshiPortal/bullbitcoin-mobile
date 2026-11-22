import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/commcenter/announcement.dart';
import 'package:bbx_api/src/commcenter/commcenter_wire.dart';
import 'package:bbx_api/src/commcenter/support_message.dart';
import 'package:bbx_api/src/json.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The `api-commcenter` endpoint.
final class CommcenterApi {
  static const endpoint = '/ak/api-commcenter';

  final BbxTransport _transport;

  @internal
  CommcenterApi(this._transport);

  /// One page of announcements, most recently updated first. A missing
  /// result or element list is empty.
  Future<Result<List<Announcement>, BbxFailure>> listAnnouncements({
    int page = 1,
    int pageSize = 5,
  }) => _transport.request(
    endpoint,
    'listAnnouncements',
    params: {
      'paginator': {'pageSize': pageSize, 'page': page},
      'sortBy': {'id': 'updatedAt', 'sort': 'desc'},
    },
    read: (result) {
      final element = read<Map<String, dynamic>?>(result, 'result');
      if (element == null) return const [];
      return readList(element['elements'], 'elements', parseAnnouncement);
    },
  );

  /// One page of the user's support chat messages, newest first. A missing
  /// element list is empty; a missing result is a format error.
  Future<Result<List<SupportMessage>, BbxFailure>> listMessages({
    int page = 1,
    int pageSize = 10,
  }) => _transport.request(
    endpoint,
    'listMessages',
    params: {
      'sortBy': {'id': 'createdAt', 'sort': 'desc'},
      'paginator': {'page': page, 'pageSize': pageSize},
    },
    read: (result) => readList(
      read<Map<String, dynamic>>(result, 'result')['elements'],
      'elements',
      parseSupportMessage,
    ),
  );

  /// Sends [text] to support from [source]. A `null` [attachments] is sent
  /// as `null`.
  Future<Result<void, BbxFailure>> sendMessageToSupport({
    required String text,
    required String source,
    List<NewSupportAttachment>? attachments,
  }) => _transport.request(
    endpoint,
    'sendMessageToSupport',
    params: {
      'element': {
        'text': text,
        'source': source,
        'attachments': attachments?.map(newSupportAttachmentToJson).toList(),
      },
    },
    read: (_) {},
  );

  /// The attachment [attachmentId] with its file data. A missing result is a
  /// format error.
  Future<Result<SupportAttachment, BbxFailure>> getMessageAttachment(
    String attachmentId,
  ) => _transport.request(
    endpoint,
    'getMessageAttachment',
    params: {'attachmentId': attachmentId},
    read: (result) =>
        parseSupportAttachment(read<Map<String, dynamic>>(result, 'result')),
  );
}
