import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/ui/screens/lightning_address_activation_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum LightningAddressRoute {
  lightningAddressSettings('lightning-address');

  final String path;

  const LightningAddressRoute(this.path);
}

class LightningAddressRoutes {
  const LightningAddressRoutes._();

  static final route = GoRoute(
    name: LightningAddressRoute.lightningAddressSettings.name,
    path: LightningAddressRoute.lightningAddressSettings.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<LightningAddressActivationCubit>(),
      child: const LightningAddressActivationScreen(),
    ),
  );
}
