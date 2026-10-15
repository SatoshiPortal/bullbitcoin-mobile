import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';

/// A custom RecoverBull key-server address that the client will accept.
///
/// Same rule as `KeyServer` in recoverbull-client-dart, narrowed to the app's Tor-only policy: plain HTTP to a `.onion` host, without credentials, query or fragment. The client replaces the path with each endpoint, so a lone trailing slash is dropped and any other path is refused rather than silently ignored.
final class KeyServerUrl {
  final Uri uri;

  const KeyServerUrl._(this.uri);

  static Result<KeyServerUrl, InvalidKeyServerUrlFailure> parse(String input) {
    Err<KeyServerUrl, InvalidKeyServerUrlFailure> reject(
      KeyServerUrlRejection reason,
    ) => Err(InvalidKeyServerUrlFailure(reason));

    final text = input.trim();
    if (text.isEmpty) return reject(KeyServerUrlRejection.empty);

    final uri = Uri.tryParse(text);
    if (uri == null) return reject(KeyServerUrlRejection.invalid);
    if (uri.scheme.toLowerCase() != 'http') {
      return reject(KeyServerUrlRejection.notHttp);
    }
    if (!uri.hasAuthority || uri.host.isEmpty) {
      return reject(KeyServerUrlRejection.invalid);
    }
    // The host, not the whole string: http://evil.com/a.onion is not onion.
    if (!uri.host.toLowerCase().endsWith('.onion')) {
      return reject(KeyServerUrlRejection.notOnion);
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      return reject(KeyServerUrlRejection.hasCredentialsQueryOrFragment);
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      return reject(KeyServerUrlRejection.hasPath);
    }

    return Ok(KeyServerUrl._(uri.replace(path: '')));
  }
}
