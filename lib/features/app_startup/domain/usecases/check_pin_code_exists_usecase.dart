import 'package:bb_mobile/features/authentication/authentication_facade.dart';

class CheckPinCodeExistsUsecase {
  final AuthenticationFacade authenticationFacade;

  CheckPinCodeExistsUsecase({required this.authenticationFacade});

  Future<bool> execute() async => await authenticationFacade.isRequired();
}
