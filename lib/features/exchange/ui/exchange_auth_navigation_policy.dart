import 'package:bb_mobile/core/utils/constants.dart';

bool isAllowedExchangeAuthNavigation({
  required String requestUrl,
  required String authBaseUrl,
}) {
  final request = Uri.tryParse(requestUrl);
  if (request == null ||
      request.scheme != 'https' ||
      request.host.isEmpty ||
      request.userInfo.isNotEmpty) {
    return false;
  }

  final authOrigin = validateHttpsOrigin(
    authBaseUrl,
    configurationName: 'Bull Bitcoin auth origin',
  );
  if (request.origin == authOrigin) return true;

  if (request.origin != 'https://www.bullbitcoin.com') {
    return false;
  }

  return request.path.contains('terms') || request.path.contains('privacy');
}
