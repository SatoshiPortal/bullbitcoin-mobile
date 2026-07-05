import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

/// Pure descriptor derivation over BDK (Bitcoin) and LWK (Liquid). Ported from
/// the app's `lib/core/utils/descriptor_derivation.dart`. INTERNAL.
class DescriptorDerivation {
  /// Public (watch-only) Bitcoin descriptor for [xprv] at the given keychain.
  static String publicBitcoinDescriptorFromXprv(
    String xprv, {
    required ScriptType scriptType,
    required bool isTestnet,
    required bool internalKeychain,
  }) {
    final secretKey = bdk.DescriptorSecretKey.fromString(privateKey: xprv);
    final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
    final keychain = internalKeychain
        ? bdk.KeychainKind.internal
        : bdk.KeychainKind.external_;

    final bdk.Descriptor descriptor = switch (scriptType) {
      ScriptType.bip84 => bdk.Descriptor.newBip84(
          secretKey: secretKey, keychainKind: keychain, networkKind: networkKind),
      ScriptType.bip49 => bdk.Descriptor.newBip49(
          secretKey: secretKey, keychainKind: keychain, networkKind: networkKind),
      ScriptType.bip44 => bdk.Descriptor.newBip44(
          secretKey: secretKey, keychainKind: keychain, networkKind: networkKind),
    };
    final str = descriptor.toString();
    // Defense-in-depth: this MUST be a PUBLIC (watch-only) descriptor. bdk's
    // `toString()` is assumed to emit the xpub/tpub form, but that is a property
    // of the pinned `bdk_dart` ref — a future bump that flips it to the secret
    // form would flow the root xprv into wallet metadata / logs / Sentry. The
    // only "prv" a descriptor string can carry is an x/tprv; a public descriptor
    // never contains it. Assert in debug and hard-fail in release rather than
    // ever return a private descriptor. (Caller maps the throw to a Failure.)
    assert(!str.contains('prv'),
        'public descriptor unexpectedly contains a private key');
    if (str.contains('prv')) {
      throw const FormatException(
          'derived descriptor unexpectedly contains a private key');
    }
    return str;
  }

  /// Confidential Liquid descriptor from the [mnemonic].
  static Future<String> publicLiquidDescriptorFromMnemonic(
    String mnemonic, {
    required bool isTestnet,
  }) async {
    final descriptor = await lwk.Descriptor.newConfidential(
      network: isTestnet ? lwk.LiquidNetwork.testnet : lwk.LiquidNetwork.mainnet,
      mnemonic: mnemonic,
    );
    return descriptor.ctDescriptor;
  }
}
