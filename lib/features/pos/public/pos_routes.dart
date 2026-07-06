import 'package:bb_mobile/features/pos/presentation/pos_cubit.dart';
import 'package:bb_mobile/features/pos/ui/screens/pos_provisioning_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PosRoute {
  posSettings('point-of-sale');

  final String path;

  const PosRoute(this.path);
}

class PosRoutes {
  const PosRoutes._();

  static final route = GoRoute(
    name: PosRoute.posSettings.name,
    path: PosRoute.posSettings.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<PosCubit>(),
      child: const PosProvisioningScreen(),
    ),
  );
}
