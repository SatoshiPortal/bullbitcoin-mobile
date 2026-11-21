import 'presentation/service_status_cubit.dart';
import 'ui/service_status_page.dart';

import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum StatusCheckRoute {
  serviceStatus('/service-status');

  final String path;

  const StatusCheckRoute(this.path);
}

class StatusCheckRouter {
  static final route = GoRoute(
    name: StatusCheckRoute.serviceStatus.name,
    path: StatusCheckRoute.serviceStatus.path,
    builder: (context, state) {
      return BlocProvider(
        create: (_) => GetIt.I<ServiceStatusCubit>()..checkStatus(),
        child: const ServiceStatusPage(),
      );
    },
  );
}
