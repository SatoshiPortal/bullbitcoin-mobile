import 'package:satoshifier/satoshifier.dart';

extension WatchOnlyDescriptorExtension on WatchOnlyDescriptor {
  ExtendedPubkey get extendedPubkey => ExtendedPubkey.parse(descriptor.pubkey);

  String get masterFingerprint => descriptor.fingerprint;
  String get pubkeyFingerprint => extendedPubkey.fingerprint;

  /// Whether this watch-only descriptor can produce a PSBT.
  ///
  /// A getter must not throw: this used to call hex.decode on the fingerprint
  /// after checking only its length, so an eight-character non-hex fingerprint
  /// raised a FormatException out of a property access, in the middle of the
  /// host app deciding whether to offer PSBT signing. Descriptor.parse now
  /// rejects such a fingerprint outright, and the check here is a total
  /// function regardless of how the descriptor was constructed.
  bool get canGeneratePsbt {
    if (!Descriptor.isValidFingerprint(masterFingerprint)) return false;
    if (masterFingerprint == pubkeyFingerprint) return false;
    return true;
  }
}
