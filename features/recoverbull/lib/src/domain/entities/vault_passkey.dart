/// Public, portable parameters for a passkey-protected vault.
final class VaultPasskey {
  static const version = 1;
  final String rpId;
  final List<int> credentialId;
  final List<int> prfSalt;

  VaultPasskey({
    required this.rpId,
    required List<int> credentialId,
    required List<int> prfSalt,
  }) : credentialId = List.unmodifiable(credentialId),
       prfSalt = List.unmodifiable(prfSalt) {
    if (rpId.length > 253 ||
        !RegExp(
          r'^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$',
        ).hasMatch(rpId)) {
      throw ArgumentError('Invalid passkey RP ID');
    }
    if (credentialId.isEmpty ||
        credentialId.length > 1024 ||
        credentialId.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError('Invalid passkey credential ID');
    }
    if (prfSalt.length != 32 || prfSalt.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError('Invalid passkey PRF salt');
    }
  }
}
