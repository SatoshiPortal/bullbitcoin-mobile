import 'package:bbx_api/bbx_api.dart';
import 'package:test/test.dart';

import 'fake_http.dart';
import 'result_helpers.dart';

void main() {
  test('listAnnouncements asks api-commcenter for the latest page', () async {
    final http = FakeHttp(
      body: {
        'result': {
          'elements': [
            {
              'title': 'Maintenance',
              'description': 'Tonight',
              'updatedAt': '2026-11-20T10:00:00Z',
            },
          ],
        },
      },
    );
    final announcements = valueOf(
      await bbx(http).commcenter.listAnnouncements(),
    );

    final request = http.requests.single;
    expect(request.path, '/ak/api-commcenter');
    expect((request.data as Map)['method'], 'listAnnouncements');
    expect((request.data as Map)['params'], {
      'paginator': {'pageSize': 5, 'page': 1},
      'sortBy': {'id': 'updatedAt', 'sort': 'desc'},
    });

    final announcement = announcements.single;
    expect(announcement.title, 'Maintenance');
    expect(announcement.description, 'Tonight');
    expect(announcement.updatedAt, DateTime.utc(2026, 11, 20, 10));
  });

  for (final body in [
    {'result': null},
    {'result': <String, Object?>{}},
  ]) {
    test('$body is an empty list', () async {
      final announcements = valueOf(
        await bbx(FakeHttp(body: body)).commcenter.listAnnouncements(),
      );
      expect(announcements, isEmpty);
    });
  }

  for (final updatedAt in [null, 'not a date']) {
    test('an invalid updatedAt ($updatedAt) is a format error', () async {
      final http = FakeHttp(
        body: {
          'result': {
            'elements': [
              {'title': 't', 'description': 'd', 'updatedAt': updatedAt},
            ],
          },
        },
      );

      expect(
        await failedCall(bbx(http).commcenter.listAnnouncements()),
        isA<BbxResponseFormatFailure>(),
      );
    });
  }

  test('a JSON-RPC error is a failure', () async {
    final http = FakeHttp(
      body: {
        'error': {'code': 1},
      },
    );

    expect(
      await failedCall(bbx(http).commcenter.listAnnouncements()),
      isA<BbxRpcFailure>(),
    );
  });
}
