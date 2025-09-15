import 'package:bb_mobile/core/ark/usecases/create_ark_secret_usecase.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/ark_setup/presentation/cubit.dart';
import 'package:bb_mobile/features/ark_setup/setup_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ArkSetupRoute {
  arkSetup('/ark/setup');

  final String path;

  const ArkSetupRoute(this.path);
}

class ArkSetupRouter {
  static final route = GoRoute(
    name: ArkSetupRoute.arkSetup.name,
    path: ArkSetupRoute.arkSetup.path,
    builder:
        (context, state) => BlocProvider(
          create:
              (context) => ArkSetupCubit(
                getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
                createArkSecretUsecase: locator<CreateArkSecretUsecase>(),
              ),
          child: const ArkSetupPage(),
        ),
  );
}
