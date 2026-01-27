import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/features/status_check/service_status_page.dart';
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
        create: (_) => sl<ServiceStatusCubit>()..checkStatus(),
        child: const ServiceStatusPage(),
      );
    },
  );
}
