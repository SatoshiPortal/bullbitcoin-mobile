import 'package:bb_mobile/features/labels/ui/page.dart';
import 'package:go_router/go_router.dart';

enum LabelsRoute {
  labels('/labels');

  final String path;

  const LabelsRoute(this.path);
}

class LabelsRouter {
  static final route = GoRoute(
    name: LabelsRoute.labels.name,
    path: LabelsRoute.labels.path,
    builder: (context, state) => const Bip329LabelsPage(),
  );
}
