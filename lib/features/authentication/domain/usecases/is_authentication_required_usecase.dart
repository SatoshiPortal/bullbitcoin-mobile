import 'package:bb_mobile/features/authentication/applications/authentication_port.dart';

class IsAuthenticationRequiredUsecase {
  final AuthenticationPort _authentication;

  IsAuthenticationRequiredUsecase({required AuthenticationPort authentication})
    : _authentication = authentication;

  Future<bool> execute() async => await _authentication.isRequired();
}
