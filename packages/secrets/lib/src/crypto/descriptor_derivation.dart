import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:primitives/primitives.dart';

/// Pure descriptor derivation over BDK (Bitcoin) and LWK (Liquid). Ported from
/// the app's `lib/core/utils/descriptor_derivation.dart`. INTERNAL.
class DescriptorDerivation {
  /// A descriptor string leaks private key material iff it carries an
  /// `xprv`/`tprv` extended-private-key token. Such a token only appears at a
  /// key-expression BOUNDARY — right after an origin `]`, a function `(`, or a
  /// `,` separator (e.g. `wpkh([fp/84h/0h/0h]xprv…/0/*)`).
  ///
  /// A bare `contains('prv')` — or even `contains('xprv')` — false-positives on
  /// the ~111-char base58 xpub/tpub body and the bech32 descriptor checksum,
  /// whose alphabets both include `p`,`r`,`v` (and can, rarely, spell `xprv`
  /// outright). Because the account xpub is DETERMINISTIC per seed, such a
  /// false positive fails closed on EVERY derivation forever — bricking ~1 in
  /// 1000 wallets. Anchoring the match to the boundary removes that class of
  /// false positive while still catching a genuine private descriptor.
  static final RegExp _privateKeyToken = RegExp(r'[\](,][xt]prv');

  /// True iff [descriptor] carries an `xprv`/`tprv` private key (see
  /// [_privateKeyToken]). Shared by this class and the derivation adapter's
  /// release-path defense-in-depth so both use the same anchored logic.
  static bool descriptorContainsPrivateKey(String descriptor) =>
      _privateKeyToken.hasMatch(descriptor);

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
    // form would flow the root xprv into wallet metadata / logs / Sentry. Match
    // a boundary-anchored xprv/tprv token (NOT a bare `contains('prv')`, which
    // false-positives on the xpub body / checksum — see
    // [descriptorContainsPrivateKey]). Assert in debug and hard-fail in release
    // rather than ever return a private descriptor. (Caller maps the throw.)
    assert(!descriptorContainsPrivateKey(str),
        'public descriptor unexpectedly contains a private key');
    if (descriptorContainsPrivateKey(str)) {
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
