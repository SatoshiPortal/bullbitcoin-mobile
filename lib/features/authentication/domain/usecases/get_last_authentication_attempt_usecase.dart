import 'package:bb_mobile/features/authentication/applications/authentication_port.dart';
import 'package:bb_mobile/features/authentication/primitives/attempt.dart';

class GetLastAuthenticationAttemptUsecase {
  final AuthenticationPort _authenticationPort;

  GetLastAuthenticationAttemptUsecase({
    required AuthenticationPort authenticationPort,
  }) : _authenticationPort = authenticationPort;

  Future<Attempt?> execute() async {
    return await _authenticationPort.fetchLastAttempt();
  }
}
