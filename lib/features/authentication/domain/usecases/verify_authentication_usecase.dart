import 'package:bb_mobile/features/authentication/applications/authentication_port.dart';
import 'package:bb_mobile/features/authentication/domain/authentication_model.dart';
import 'package:bb_mobile/features/authentication/primitives/attempt.dart';

class VerifyAuthenticationUsecase {
  final AuthenticationPort _authentication;

  VerifyAuthenticationUsecase({required AuthenticationPort authentication})
    : _authentication = authentication;

  Future<Attempt> execute(AuthenticationModel model) async {
    return await _authentication.verify(model.toApplication());
  }
}
