import 'package:bb_mobile/features/authentication/applications/authentication_application.dart';
import 'package:bb_mobile/features/authentication/primitives/attempt.dart';

abstract class AuthenticationPort {
  Future<void> enable(AuthenticationApplication authentication);
  Future<void> disable();
  Future<bool> isRequired();
  Future<Attempt> verify(AuthenticationApplication authentication);
  Future<Attempt?> fetchLastAttempt();
}
