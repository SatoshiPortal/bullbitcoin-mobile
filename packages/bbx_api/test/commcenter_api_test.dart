import 'package:bbx_api/bbx_api.dart';
import 'package:test/test.dart';

import 'fake_http.dart';

void main() {
  test('listAnnouncements asks api-commcenter for the latest page', () async {
    final dio = FakeHttp.dio(
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
    final announcements = await BbxApiClient(dio).commcenter
        .listAnnouncements();

    final request = (dio.httpClientAdapter as FakeHttp).requests.single;
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
      expect(
        await BbxApiClient(FakeHttp.dio(body: body)).commcenter
            .listAnnouncements(),
        isEmpty,
      );
    });
  }

  for (final updatedAt in [null, 'not a date']) {
    test('an invalid updatedAt ($updatedAt) is a format error', () async {
      await expectLater(
        BbxApiClient(
          FakeHttp.dio(
            body: {
              'result': {
                'elements': [
                  {'title': 't', 'description': 'd', 'updatedAt': updatedAt},
                ],
              },
            },
          ),
        ).commcenter.listAnnouncements(),
        throwsA(isA<BbxApiFormatException>()),
      );
    });
  }

  test('a JSON-RPC error throws', () async {
    await expectLater(
      BbxApiClient(
        FakeHttp.dio(
          body: {
            'error': {'code': 1},
          },
        ),
      ).commcenter.listAnnouncements(),
      throwsA(isA<BbxApiRpcException>()),
    );
  });
}
