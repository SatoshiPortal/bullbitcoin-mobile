import 'package:bb_mobile/features/authentication/applications/authentication_application.dart';

class AuthenticationModel {
  AuthenticationApplication toApplication() {
    switch (this) {
      case PinModel(value: String value):
        return PinApplication(value: value);
      case AuthenticationModel():
        return AuthenticationApplication();
    }
  }
}

class PinModel extends AuthenticationModel {
  final String value;

  PinModel({required this.value});
}
