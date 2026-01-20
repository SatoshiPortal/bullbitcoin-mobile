import 'package:bb_mobile/features/authentication/authentication.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/disable_authentication_usecase.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/enable_authentication.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/is_authentication_required_usecase.dart';
import 'package:bb_mobile/features/authentication/domain/usecases/verify_authentication_usecase.dart';
import 'package:bb_mobile/features/authentication/primitives/attempt.dart';

export 'primitives/attempt.dart';
export 'primitives/authentication_status.dart';
export 'authentication.dart';
export 'locator.dart';
export 'presentation/unlock/app_unlock_router.dart';

class AuthenticationFacade {
  final IsAuthenticationRequiredUsecase _isAuthenticationRequiredUsecase;
  final VerifyAuthenticationUsecase _verifyAuthenticationUsecase;
  final DisableAuthenticationUsecase _disableAuthenticationUsecase;
  final EnableAuthenticationUsecase _enableAuthenticationUsecase;

  AuthenticationFacade({
    required IsAuthenticationRequiredUsecase isAuthenticationRequiredUsecase,
    required VerifyAuthenticationUsecase verifyAuthenticationUsecase,
    required DisableAuthenticationUsecase disableAuthenticationUsecase,
    required EnableAuthenticationUsecase enableAuthenticationUsecase,
  }) : _isAuthenticationRequiredUsecase = isAuthenticationRequiredUsecase,
       _verifyAuthenticationUsecase = verifyAuthenticationUsecase,
       _disableAuthenticationUsecase = disableAuthenticationUsecase,
       _enableAuthenticationUsecase = enableAuthenticationUsecase;

  Future<bool> isRequired() async =>
      await _isAuthenticationRequiredUsecase.execute();

  Future<Attempt> verify(Authentication authentication) async {
    return await _verifyAuthenticationUsecase.execute(authentication.toModel());
  }

  Future<void> disable() async => await _disableAuthenticationUsecase.execute();

  Future<void> enable(Authentication authentication) async =>
      await _enableAuthenticationUsecase.execute(authentication.toModel());
}
