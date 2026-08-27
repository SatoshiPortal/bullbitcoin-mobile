import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_coldcard/import_coldcard_page.dart';
import 'package:go_router/go_router.dart';

enum ImportColdcardRoute {
  importColdcardQ('/import-coldcard-q'),
  importColdcardMk4('/import-coldcard-mk4');

  final String path;

  const ImportColdcardRoute(this.path);
}

class ImportColdcardRouter {
  static final routes = [
    GoRoute(
      name: ImportColdcardRoute.importColdcardQ.name,
      path: ImportColdcardRoute.importColdcardQ.path,
      builder: (context, state) =>
          ImportColdcardPage(signerDevice: SignerDeviceEntity.coldcardQ),
    ),
    GoRoute(
      name: ImportColdcardRoute.importColdcardMk4.name,
      path: ImportColdcardRoute.importColdcardMk4.path,
      builder: (context, state) =>
          ImportColdcardPage(signerDevice: SignerDeviceEntity.coldcardMk4),
    ),
  ];
}
