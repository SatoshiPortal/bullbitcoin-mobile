/// A wallet definition. Identity and descriptors match the native store.
final class RegisteredWallet {
  final String id;
  final String? secretFingerprint;
  final String masterFingerprint;
  final String signer;
  final String network;
  final String xpub;
  final String externalDescriptor;
  final String internalDescriptor;
  final String? label;
  final String? birthday;
  final bool isDefault;

  const RegisteredWallet({
    required this.id,
    required this.secretFingerprint,
    required this.masterFingerprint,
    required this.signer,
    required this.network,
    required this.xpub,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.label,
    required this.birthday,
    required this.isDefault,
  });
}

/// A descriptor projection for chain synchronization.
///
/// Liquid confidential descriptors contain blinding material. These values
/// must only reach the native wallet and must never be logged.
final class RegisteredWalletDescriptor {
  final String id;
  final String network;
  final String externalDescriptor;
  final String internalDescriptor;

  const RegisteredWalletDescriptor({
    required this.id,
    required this.network,
    required this.externalDescriptor,
    required this.internalDescriptor,
  });
}
