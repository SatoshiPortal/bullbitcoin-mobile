class AuthenticationApplication {}

class PinApplication extends AuthenticationApplication {
  final String value;

  PinApplication({required this.value});
}
