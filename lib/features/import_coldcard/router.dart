import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_coldcard/import_coldcard_page.dart';
import 'package:go_router/go_router.dart';

enum ImportColdcardRoute {
  importColdcard('/import-coldcard');

  final String path;

  const ImportColdcardRoute(this.path);
}

class ImportColdcardRouter {
  static final route = GoRoute(
    name: ImportColdcardRoute.importColdcard.name,
    path: ImportColdcardRoute.importColdcard.path,
    builder: (context, state) {
      final signerDevice = state.extra! as SignerDeviceEntity;
      return ImportColdcardPage(signerDevice: signerDevice);
    },
  );
}
