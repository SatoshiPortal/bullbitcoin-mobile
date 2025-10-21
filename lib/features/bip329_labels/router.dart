import 'package:bb_mobile/features/bip329_labels/page.dart';
import 'package:go_router/go_router.dart';

enum Bip329LabelsRoute {
  bip329Labels('/bip329-labels');

  final String path;

  const Bip329LabelsRoute(this.path);
}

class Bip329LabelsRouter {
  static final route = GoRoute(
    name: Bip329LabelsRoute.bip329Labels.name,
    path: Bip329LabelsRoute.bip329Labels.path,
    builder: (context, state) => const Bip329LabelsPage(),
  );
}
