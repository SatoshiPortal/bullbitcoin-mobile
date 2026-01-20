import 'package:bb_mobile/features/authentication/primitives/authentication_status.dart';

class Attempt {
  final AuthenticationStatus status;
  final int attempts;
  final Duration timeout;

  Attempt({
    required this.status,
    required this.attempts,
    required this.timeout,
  });
}
