import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';

/// Domain seam for turning a serialized v1 manifest payload back into the
/// validated [KeychainManifestFile] entity.
///
/// The concrete JSON codec lives in data/ and is injected through this port, so
/// domain code (the parse use-case) never imports the wire model: calls flow
/// down, domain never depends on data (R2-C1). It also gives the format-freeze
/// golden vectors a stable decode seam.
abstract interface class KeychainManifestFileDecoder {
  KeychainManifestFile decode(String payload);
}
