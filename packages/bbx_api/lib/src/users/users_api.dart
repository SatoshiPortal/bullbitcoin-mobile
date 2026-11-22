import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/users/user_preferences.dart';
import 'package:bbx_api/src/users/user_summary.dart';
import 'package:bbx_api/src/users/users_wire.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The `api-users` endpoint.
final class UsersApi {
  static const endpoint = '/ak/api-users';

  final BbxTransport _transport;

  @internal
  UsersApi(this._transport);

  /// The signed-in user's account, or `null` when the server returns no
  /// result.
  Future<Result<UserSummary?, BbxFailure>> getUserSummary() =>
      _transport.request(
        endpoint,
        'getUserSummary',
        read: (result) {
          final summary = read<Map<String, dynamic>?>(result, 'result');
          return summary == null ? null : parseUserSummary(summary);
        },
      );

  /// Records the user's consent to the scam warning. Returns whether the
  /// server reported `success: true`; any other result, including one that
  /// is not an object, is `false`.
  Future<Result<bool, BbxFailure>> registerResponsibilityConsent() =>
      _transport.request(
        endpoint,
        'registerResponsibilityConsent',
        read: (result) =>
            result is Map<String, dynamic> && result['success'] == true,
      );

  /// Saves [preferences], replacing the stored set.
  Future<Result<void, BbxFailure>> saveUserPreferences(
    UserPreferences preferences,
  ) => _transport.request(
    endpoint,
    'saveUserPreferences',
    params: {'userPreferences': userPreferencesToJson(preferences)},
    read: (_) {},
  );
}
