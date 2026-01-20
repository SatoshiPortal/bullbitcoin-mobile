import 'package:bb_mobile/features/authentication/domain/authentication_model.dart';

class Authentication {
  AuthenticationModel toModel() {
    switch (this) {
      case Pin(value: String value):
        return PinModel(value: value);
      case Authentication():
        return AuthenticationModel();
    }
  }
}

class Pin extends Authentication {
  final String value;

  Pin({required this.value});
}
