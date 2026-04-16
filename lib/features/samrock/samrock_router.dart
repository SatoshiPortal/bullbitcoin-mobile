import 'package:bb_mobile/features/samrock/presentation/bloc/samrock_cubit.dart';
import 'package:bb_mobile/features/samrock/ui/samrock_setup_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SamrockRoute {
  samrockSetup('/samrock-setup');

  const SamrockRoute(this.path);

  final String path;
}

class SamrockRouter {
  static final route = GoRoute(
    name: SamrockRoute.samrockSetup.name,
    path: SamrockRoute.samrockSetup.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<SamrockCubit>(),
      child: const SamrockSetupPage(),
    ),
  );
}
