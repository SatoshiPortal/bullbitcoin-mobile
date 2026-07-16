import 'package:bb_mobile/features/get_paid_settings/presentation/get_paid_settings_cubit.dart';
import 'package:bb_mobile/features/get_paid_settings/ui/get_paid_settings_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum GetPaidSettingsRoute {
  getPaidSettings('get-paid');

  final String path;
  const GetPaidSettingsRoute(this.path);
}

final class GetPaidSettingsRoutes {
  const GetPaidSettingsRoutes._();

  static final route = GoRoute(
    name: GetPaidSettingsRoute.getPaidSettings.name,
    path: GetPaidSettingsRoute.getPaidSettings.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<GetPaidSettingsCubit>()..load(),
      child: const GetPaidSettingsScreen(),
    ),
  );
}
