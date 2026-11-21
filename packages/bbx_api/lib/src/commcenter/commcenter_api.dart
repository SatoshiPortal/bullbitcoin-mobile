import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/commcenter/announcement.dart';
import 'package:bbx_api/src/commcenter/support_message.dart';
import 'package:bbx_api/src/json.dart';

/// The `api-commcenter` endpoint.
class CommcenterApi {
  static const endpoint = '/ak/api-commcenter';

  final BbxApiClient _client;

  CommcenterApi(this._client);

  /// One page of announcements, most recently updated first. A missing
  /// result or element list is empty.
  Future<List<Announcement>> listAnnouncements({
    int page = 1,
    int pageSize = 5,
  }) async {
    final result = read<Map<String, dynamic>?>(
      await _client.call(
        endpoint,
        'listAnnouncements',
        params: {
          'paginator': {'pageSize': pageSize, 'page': page},
          'sortBy': {'id': 'updatedAt', 'sort': 'desc'},
        },
      ),
      'result',
    );
    if (result == null) return const [];
    return readList(result['elements'], 'elements', Announcement.fromJson);
  }

  /// One page of the user's support chat messages, newest first. A missing
  /// element list is empty; a missing result is a format error.
  Future<List<SupportMessage>> listMessages({
    int page = 1,
    int pageSize = 10,
  }) async {
    final result = read<Map<String, dynamic>>(
      await _client.call(
        endpoint,
        'listMessages',
        params: {
          'sortBy': {'id': 'createdAt', 'sort': 'desc'},
          'paginator': {'page': page, 'pageSize': pageSize},
        },
      ),
      'result',
    );
    return readList(result['elements'], 'elements', SupportMessage.fromJson);
  }

  /// Sends [text] to support from [source]. A `null` [attachments] is sent
  /// as `null`.
  Future<void> sendMessageToSupport({
    required String text,
    required String source,
    List<NewSupportAttachment>? attachments,
  }) async {
    await _client.call(
      endpoint,
      'sendMessageToSupport',
      params: {
        'element': {
          'text': text,
          'source': source,
          'attachments': attachments?.map((a) => a.toJson()).toList(),
        },
      },
    );
  }

  /// The attachment [attachmentId] with its file data. A missing result is a
  /// format error.
  Future<SupportAttachment> getMessageAttachment(String attachmentId) async =>
      SupportAttachment.fromJson(
        read<Map<String, dynamic>>(
          await _client.call(
            endpoint,
            'getMessageAttachment',
            params: {'attachmentId': attachmentId},
          ),
          'result',
        ),
      );
}
