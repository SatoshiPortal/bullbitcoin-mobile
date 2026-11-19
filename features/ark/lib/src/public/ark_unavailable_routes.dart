import 'package:go_router/go_router.dart';

import '../ui/ark_unavailable_screen.dart';

/// Select instead of configured Ark routes, never alongside duplicate paths.
/// Captured route arguments do not authorize reads or actions in this mode.
List<GoRoute> createArkUnavailableRoutes() => [
  for (final path in ['/ark', '/ark/pay', '/ark/claim-recovery'])
    GoRoute(path: path, builder: (_, state) => const ArkUnavailableScreen()),
];
