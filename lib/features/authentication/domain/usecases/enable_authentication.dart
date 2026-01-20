import 'package:bb_mobile/features/authentication/applications/authentication_port.dart';
import 'package:bb_mobile/features/authentication/domain/authentication_model.dart';

class EnableAuthenticationUsecase {
  final AuthenticationPort _authentication;

  EnableAuthenticationUsecase({required AuthenticationPort authentication})
    : _authentication = authentication;

  Future<void> execute(AuthenticationModel model) async {
    await _authentication.enable(model.toApplication());
  }
}
