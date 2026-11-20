import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/commcenter/announcement.dart';
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
}
