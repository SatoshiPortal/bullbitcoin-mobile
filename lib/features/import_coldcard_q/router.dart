import 'package:bb_mobile/features/import_coldcard_q/import_coldcard_q_page.dart';
import 'package:go_router/go_router.dart';

enum ImportColdcardQRoute {
  home('/import-coldcard-q-home');

  final String path;

  const ImportColdcardQRoute(this.path);
}

class ImportColdcardRouter {
  static final route = GoRoute(
    name: ImportColdcardQRoute.home.name,
    path: ImportColdcardQRoute.home.path,
    builder: (context, state) => const ImportColdcardQPage(),
  );
}
