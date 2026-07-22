import 'package:bb_mobile/features/coldcard_firmware/presentation/cubit/coldcard_firmware_cubit.dart';
import 'package:bb_mobile/features/coldcard_firmware/ui/screens/coldcard_model_select_screen.dart';
import 'package:bb_mobile/features/coldcard_firmware/ui/screens/coldcard_update_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:coldcard_firmware/coldcard_firmware.dart' show ColdcardModel;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ColdcardFirmwareRoute {
  coldcardUpdate('/coldcard-update'),
  coldcardUpdateDevice('/coldcard-update/device');

  final String path;

  const ColdcardFirmwareRoute(this.path);
}

class ColdcardFirmwareRouter {
  static final routes = [
    GoRoute(
      name: ColdcardFirmwareRoute.coldcardUpdate.name,
      path: ColdcardFirmwareRoute.coldcardUpdate.path,
      builder: (context, state) => const ColdcardModelSelectScreen(),
    ),
    GoRoute(
      name: ColdcardFirmwareRoute.coldcardUpdateDevice.name,
      path: ColdcardFirmwareRoute.coldcardUpdateDevice.path,
      redirect: (_, state) => state.extra is ColdcardModel
          ? null
          : ColdcardFirmwareRoute.coldcardUpdate.path,
      builder: (context, state) {
        final model = state.extra;
        if (model is! ColdcardModel) {
          return const ColdcardModelSelectScreen();
        }
        return BlocProvider(
          create: (_) => locator<ColdcardFirmwareCubit>()..loadLatest(model),
          child: const ColdcardUpdateScreen(),
        );
      },
    ),
  ];
}
