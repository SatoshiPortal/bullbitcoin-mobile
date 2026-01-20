import 'package:bb_mobile/features/authentication/authentication_facade.dart';

// On iOS especially, some secure storage data might still be there after the app is uninstalled.
// This use case is used to reset the app data when the app is installed again.
class ResetAppDataUsecase {
  final AuthenticationFacade _authenticationFacade;

  ResetAppDataUsecase({required AuthenticationFacade authenticationFacade})
    : _authenticationFacade = authenticationFacade;

  Future<void> execute() async => await _authenticationFacade.disable();
}
