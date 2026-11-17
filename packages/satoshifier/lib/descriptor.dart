import 'package:bip32_keys/bip32_keys.dart';
import 'package:satoshifier/satoshifier.dart';
import 'package:satoshifier/utils/descriptor_checksum.dart';

class Descriptor {
  final ScriptOperand operand;
  final String fingerprint;
  final String pubkey;
  final Network network;
  final Derivation derivation;
  final int account;

  Descriptor({
    required this.operand,
    required this.fingerprint,
    required this.pubkey,
    required this.network,
    required this.derivation,
    required this.account,
  });

  String get origin {
    if (fingerprint.isEmpty) return '';
    return '[$fingerprint/${derivation.purpose}/${coinType.value}h/${account}h]';
  }

  bool get _isShwpkh => operand == ScriptOperand.shwpkh;

  String get combined {
    return "${operand.value}($origin$pubkey/<0;1>/*)${_isShwpkh ? ')' : ''}";
  }

  String get internal {
    return "${operand.value}($origin$pubkey/1/*)${_isShwpkh ? ')' : ''}";
  }

  String get external {
    return "${operand.value}($origin$pubkey/0/*)${_isShwpkh ? ')' : ''}";
  }

  CoinType get coinType => network.isBitcoin
      ? network == Network.bitcoinMainnet
            ? CoinType.bitcoin
            : CoinType.testnet
      : CoinType.liquid;

  static Descriptor parse(String string) {
    final descriptor = string.trim();
    // Checked before any parser runs: the three below swallow their errors to
    // fall through to each other, so a checksum failure raised inside one of
    // them would be indistinguishable from "wrong descriptor shape".
    if (!DescriptorChecksum.isValid(descriptor)) {
      // Without the descriptor: it can embed a private key, and this is a
      // path a malformed paste reaches routinely.
      throw FormatException('Invalid descriptor checksum');
    }
    try {
      return fromCombinedDescriptor(descriptor);
    } catch (_) {}

    try {
      return fromExternalDescriptor(descriptor);
    } catch (_) {}

    try {
      return parseExtendedPublicKeyWithKeyOrigin(descriptor);
    } catch (_) {}

    throw 'Invalid descriptor format';
  }

  static Descriptor fromCombinedDescriptor(String descriptor) {
    final combinedDescriptorPattern = RegExp(
      r'(\w+)\(\[([a-fA-F0-9]+)/([0-9]+h)/([0-9]+h)/([0-9]+h)\]/?([^/<]+)',
    );

    return parseDescriptorWithOrigin(
      pattern: combinedDescriptorPattern,
      descriptor: descriptor,
      errorMessage: 'Not a combined descriptor: $descriptor',
      useOperandFromRegex: false,
    );
  }

  static Descriptor fromExternalDescriptor(String descriptor) {
    final externalDescriptorPattern = RegExp(
      r"(\w+(?:\(\w+)?)\(\[([a-fA-F0-9]+)/([0-9]+[\'h])/([0-9]+[\'h])/([0-9]+[\'h])\]([^/]+)/0/\*\)(?:#[a-zA-Z0-9]+)?$",
    );

    return parseDescriptorWithOrigin(
      pattern: externalDescriptorPattern,
      descriptor: descriptor,
      errorMessage: 'Not an external descriptor: $descriptor',
      useOperandFromRegex: true,
    );
  }

  static Descriptor fromExtendedPubkey(ExtendedPubkey extendedPubkey) {
    return Descriptor(
      operand: ScriptOperand.fromExtendedPubkey(extendedPubkey),
      fingerprint: '',
      pubkey: extendedPubkey.xpub,
      network: extendedPubkey.network,
      derivation: extendedPubkey.derivation,
      account: 0,
    );
  }

  /// A BIP32 key-origin fingerprint: exactly four bytes as hex.
  ///
  /// The three parse paths validated this inconsistently — the regexes allowed
  /// hex of any length, the '[origin]xpub' path allowed anything at all — and
  /// the length was in practice only checked much later, by
  /// WatchOnlyDescriptorExtension.canGeneratePsbt, which then called
  /// hex.decode on it. An eight-character non-hex fingerprint such as
  /// 'zzzzzzzz' parsed, and the FormatException surfaced out of a boolean
  /// getter while the host app was deciding whether to offer PSBT signing.
  static bool isValidFingerprint(String fingerprint) =>
      _fingerprintPattern.hasMatch(fingerprint);

  static final RegExp _fingerprintPattern = RegExp(r'^[0-9a-fA-F]{8}$');

  /// Rejects a descriptor whose key-origin coin type and extended key disagree
  /// about the network.
  ///
  /// The network used to come from the coin-type component of the origin path
  /// alone, and the key's own version bytes — the authoritative,
  /// checksum-protected signal — were never looked at. A mainnet xpub under a
  /// testnet path was reported as bitcoinTestnet, and a tpub under /0h/ as
  /// bitcoinMainnet. Either way a single wrong character in the path silently
  /// produced a plausible wallet on the wrong chain: mainnet UTXOs that never
  /// appear, or real BTC sent to addresses derived from a throwaway testnet key.
  ///
  /// Compared at mainnet-versus-testnet granularity, which is what the version
  /// bytes actually encode. Comparing the exact network would reject Liquid,
  /// whose coin type 1776 legitimately carries an xpub.
  ///
  /// A prefix this package does not know is left alone rather than refused:
  /// parseDescriptorWithOrigin deliberately accepts descriptor flavours that
  /// ExtendedPubkey.parse would reject, and this check is not the place to
  /// narrow that.
  static void _checkKeyNetworkMatchesPath(String xpub, Network pathNetwork) {
    final XpubType keyType;
    try {
      keyType = XpubType.fromString(xpub);
    } catch (_) {
      return;
    }
    if (Network.fromXpubType(keyType).isMainnet != pathNetwork.isMainnet) {
      throw FormatException(
        'Key-origin coin type and extended key disagree on the network',
      );
    }
  }

  static Descriptor fromStrings({
    required String fingerprint,
    required String path,
    required String xpub,
  }) {
    if (!isValidFingerprint(fingerprint)) {
      throw FormatException('Invalid key-origin fingerprint');
    }
    try {
      Bip32Keys.fromBase58(xpub, bypassVersion: true);
    } on ArgumentError {
      throw FormatException('Invalid extended public key in descriptor');
    }
    final convertedPath = path.startsWith('m/') ? path.substring(2) : path;

    final pathParts = convertedPath.split('/');
    if (pathParts.length < 3) {
      throw 'Invalid descriptor format: insufficient path components';
    }

    final purpose = pathParts[0];
    final coinTypeString = pathParts[1];
    final accountString = pathParts[2];

    final coinTypeInt = int.parse(Utils.trimLastQuoteOrH(coinTypeString));
    final account = int.parse(Utils.trimLastQuoteOrH(accountString));

    final derivation = Derivation.fromPurpose(purpose);
    final coinType = CoinType.fromInt(coinTypeInt);
    final network = coinType.toNetwork();
    _checkKeyNetworkMatchesPath(xpub, network);
    final operand = switch (derivation) {
      Derivation.bip44 => ScriptOperand.pkh,
      Derivation.bip49 => ScriptOperand.shwpkh,
      Derivation.bip84 => ScriptOperand.wpkh,
    };

    return Descriptor(
      operand: operand,
      fingerprint: fingerprint,
      pubkey: xpub,
      network: network,
      derivation: derivation,
      account: account,
    );
  }

  static Descriptor parseDescriptorWithOrigin({
    required RegExp pattern,
    required String descriptor,
    required String errorMessage,
    required bool useOperandFromRegex,
  }) {
    final match = pattern.firstMatch(descriptor.trim());

    if (match == null) throw errorMessage;

    final operandString = match.group(1)!;
    final fingerprint = match.group(2)!;
    if (!isValidFingerprint(fingerprint)) {
      throw FormatException('Invalid key-origin fingerprint');
    }
    final derivationPurpose = match.group(3)!;
    final coinTypeString = match.group(4)!;
    final accountString = match.group(5)!;
    final pubkey = match.group(6)!;
    // The key travels inside the descriptor as an opaque substring, so
    // nothing else verifies it. Check the base58check trailer here rather
    // than through ExtendedPubkey.parse, which additionally insists on a
    // known SLIP-132 prefix and would reject descriptor flavours this parser
    // accepts today.
    try {
      Bip32Keys.fromBase58(pubkey, bypassVersion: true);
    } on ArgumentError {
      throw FormatException('Invalid extended public key in descriptor');
    }

    final operand = useOperandFromRegex
        ? ScriptOperand.fromDescriptor(operandString)
        : ScriptOperand.fromDescriptor(descriptor);
    final derivation = Derivation.fromPurpose(derivationPurpose);
    final coinTypeInt = int.parse(Utils.trimLastQuoteOrH(coinTypeString));
    final coinType = CoinType.fromInt(coinTypeInt);
    final network = coinType.toNetwork();
    _checkKeyNetworkMatchesPath(pubkey, network);
    final account = int.parse(Utils.trimLastQuoteOrH(accountString));

    return Descriptor(
      operand: operand,
      fingerprint: fingerprint,
      pubkey: pubkey,
      network: network,
      derivation: derivation,
      account: account,
    );
  }

  static Descriptor parseExtendedPublicKeyWithKeyOrigin(String descriptor) {
    if (!descriptor.startsWith('[') ||
        !descriptor.contains(']') ||
        !descriptor.contains('pub')) {
      throw 'Invalid descriptor format: missing key origin';
    }

    final bracketEnd = descriptor.indexOf(']');
    if (bracketEnd <= 0) {
      throw 'Invalid descriptor format: missing closing bracket';
    }

    final bracketContent = descriptor.substring(1, bracketEnd);
    final parts = bracketContent.split('/');
    if (parts.length < 2) {
      throw 'Invalid descriptor format: insufficient derivation path parts';
    }

    final fingerprint = parts[0];
    final path = parts.sublist(1).join('/');
    final xpub = descriptor.substring(bracketEnd + 1);

    return fromStrings(fingerprint: fingerprint, path: path, xpub: xpub);
  }
}
