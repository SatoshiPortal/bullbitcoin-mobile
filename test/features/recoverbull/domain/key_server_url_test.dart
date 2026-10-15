import 'dart:io';

import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/key_server_url.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

const _onion = 'http://abc.onion';

Uri _accepted(String input) {
  final result = KeyServerUrl.parse(input);
  expect(result, isA<Ok<KeyServerUrl, InvalidKeyServerUrlFailure>>());
  return (result as Ok<KeyServerUrl, InvalidKeyServerUrlFailure>).value.uri;
}

KeyServerUrlRejection _rejected(String input) {
  final result = KeyServerUrl.parse(input);
  expect(result, isA<Err<KeyServerUrl, InvalidKeyServerUrlFailure>>());
  return (result as Err<KeyServerUrl, InvalidKeyServerUrlFailure>)
      .failure
      .reason;
}

void main() {
  group('accepted', () {
    for (final (input, expected) in [
      (SettingsConstants.recoverbullUrl, SettingsConstants.recoverbullUrl),
      (_onion, _onion),
      ('HTTP://ABC.ONION', _onion),
      ('http://abc.onion:80', _onion),
      ('http://abc.onion:8080', 'http://abc.onion:8080'),
      ('http://abc.onion/', _onion),
      ('  http://abc.onion  ', _onion),
    ]) {
      test('$input -> $expected', () {
        final uri = _accepted(input);
        expect(uri.toString(), expected);

        // Whatever is accepted here must also pass the client's own check.
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        expect(
          () => recoverbull.KeyServer(address: uri, client: client),
          returnsNormally,
        );
      });
    }
  });

  group('rejected', () {
    for (final (input, reason) in [
      ('', KeyServerUrlRejection.empty),
      ('   ', KeyServerUrlRejection.empty),
      ('http://[::1', KeyServerUrlRejection.invalid),
      ('http:abc.onion', KeyServerUrlRejection.invalid),
      ('abc.onion', KeyServerUrlRejection.notHttp),
      ('https://abc.onion', KeyServerUrlRejection.notHttp),
      ('ftp://abc.onion', KeyServerUrlRejection.notHttp),
      ('http://evil.com/a.onion', KeyServerUrlRejection.notOnion),
      ('http://abc.onion.evil.com', KeyServerUrlRejection.notOnion),
      ('http://localhost', KeyServerUrlRejection.notOnion),
      (
        'http://user:pass@abc.onion',
        KeyServerUrlRejection.hasCredentialsQueryOrFragment,
      ),
      (
        'http://abc.onion?x=.onion',
        KeyServerUrlRejection.hasCredentialsQueryOrFragment,
      ),
      (
        'http://abc.onion#.onion',
        KeyServerUrlRejection.hasCredentialsQueryOrFragment,
      ),
      ('http://abc.onion/api', KeyServerUrlRejection.hasPath),
    ]) {
      test('"$input" -> ${reason.name}', () {
        expect(_rejected(input), reason);
      });
    }
  });
}
