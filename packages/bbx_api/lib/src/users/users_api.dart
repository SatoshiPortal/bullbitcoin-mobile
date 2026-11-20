import 'package:bbx_api/src/bbx_api_client.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/users/user_preferences.dart';
import 'package:bbx_api/src/users/user_summary.dart';

/// The `api-users` endpoint.
class UsersApi {
  static const endpoint = '/ak/api-users';

  final BbxApiClient _client;

  UsersApi(this._client);

  /// The signed-in user's account, or `null` when the server returns no
  /// result.
  Future<UserSummary?> getUserSummary() async {
    final result = read<Map<String, dynamic>?>(
      await _client.call(endpoint, 'getUserSummary'),
      'result',
    );
    return result == null ? null : UserSummary.fromJson(result);
  }

  /// Records the user's consent to the scam warning. Returns whether the
  /// server reported `success: true`.
  Future<bool> registerResponsibilityConsent() async {
    final result = read<Map<String, dynamic>?>(
      await _client.call(endpoint, 'registerResponsibilityConsent'),
      'result',
    );
    return result?['success'] == true;
  }

  /// Saves [preferences], replacing the stored set.
  Future<void> saveUserPreferences(UserPreferences preferences) async {
    await _client.call(
      endpoint,
      'saveUserPreferences',
      params: {'userPreferences': preferences.toJson()},
    );
  }
}
