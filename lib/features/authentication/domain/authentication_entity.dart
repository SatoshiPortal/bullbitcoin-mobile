class AuthenticationEntity {}

class PinEntity extends AuthenticationEntity {
  final String value;

  PinEntity({required this.value});
}
