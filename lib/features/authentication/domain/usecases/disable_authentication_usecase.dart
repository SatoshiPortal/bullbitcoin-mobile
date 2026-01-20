import 'package:bb_mobile/features/authentication/applications/authentication_port.dart';

class DisableAuthenticationUsecase {
  final AuthenticationPort _authentication;

  DisableAuthenticationUsecase({required AuthenticationPort authentication})
    : _authentication = authentication;

  Future<void> execute() async => await _authentication.disable();
}
