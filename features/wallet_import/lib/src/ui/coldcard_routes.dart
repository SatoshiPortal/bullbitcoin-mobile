import 'package:signers/signers.dart';
import 'package:wallet_import/src/ui/import_coldcard_page.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show ImageProvider;

enum ImportColdcardRoute {
  importColdcardQ('/import-coldcard-q'),
  importColdcardMk4('/import-coldcard-mk4');

  final String path;

  const ImportColdcardRoute(this.path);
}

class ImportColdcardRouter {
  static List<GoRoute> routes(ImageProvider<Object> illustration) => [
    GoRoute(
      name: ImportColdcardRoute.importColdcardQ.name,
      path: ImportColdcardRoute.importColdcardQ.path,
      builder: (context, state) => ImportColdcardPage(
        signerDevice: SignerDevice.coldcardQ,
        qrIllustration: illustration,
      ),
    ),
    GoRoute(
      name: ImportColdcardRoute.importColdcardMk4.name,
      path: ImportColdcardRoute.importColdcardMk4.path,
      builder: (context, state) => ImportColdcardPage(
        signerDevice: SignerDevice.coldcardMk4,
        qrIllustration: illustration,
      ),
    ),
  ];
}
