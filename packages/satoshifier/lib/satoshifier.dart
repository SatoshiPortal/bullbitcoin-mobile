library;

// exports
export 'enums/network.dart' show Network;
export 'enums/xpub_type.dart' show XpubType;
export 'enums/coin_type.dart' show CoinType;
export 'enums/derivation.dart' show Derivation;
export 'descriptor.dart' show Descriptor;
export 'enums/script_operand.dart' show ScriptOperand;
export 'extended_pubkey.dart' show ExtendedPubkey;
export 'parsers/watch_only_xpub_parser.dart' show WatchOnlyXpubParser;
export 'parsers/watch_only_descriptor_parser.dart'
    show WatchOnlyDescriptorParser;
export 'watch_only_descriptor_extension.dart' show WatchOnlyDescriptorExtension;
export 'parsers/bitcoin_address_parser.dart' show BitcoinAddressParser;
export 'parsers/bip21_parser.dart' show Bip21Parser;
export 'parsers/bolt11_parser.dart' show Bolt11Parser;
export 'parsers/liquid_address_parser.dart' show LiquidAddressParser;
export 'parsers/psbt_parser.dart' show PsbtParser;
export 'parsers/lnurl_parser.dart' show LnurlParser;

export 'utils/utils.dart' show Utils;
export 'utils/bip32_utils.dart' show Bip32Utils;

// imports
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:satoshifier/descriptor.dart';
import 'package:satoshifier/enums/network.dart';
import 'package:satoshifier/extended_pubkey.dart';
import 'package:satoshifier/registry.dart';

part 'satoshifier.freezed.dart';

@freezed
sealed class Satoshifier with _$Satoshifier {
  const factory Satoshifier.bitcoinAddress({
    required String address,
    required Network network,
  }) = BitcoinAddress;

  const factory Satoshifier.liquidAddress({
    required String address,
    required Network network,
  }) = LiquidAddress;

  const factory Satoshifier.lightningInvoice({required String invoice}) =
      LightningInvoice;

  const factory Satoshifier.bolt11({
    required String invoice,
    required int sats,

    /// The invoice amount as encoded, in millisatoshis.
    ///
    /// BOLT11 denominates in msats and the pico-BTC multiplier makes
    /// sub-satoshi amounts expressible, so [sats] cannot represent every
    /// invoice. Use this for anything that must be exact; [sats] is a
    /// rounded-up view for display and balance checks.
    @Default(0) int msats,
    required String paymentHash,
    @Default('') String description,
    required int expiresAt,
    required bool isTestnet,
  }) = Bolt11;

  const factory Satoshifier.watchOnly({required Descriptor descriptor}) =
      WatchOnly;

  const factory Satoshifier.bip21({
    required String scheme,
    required String uri,
    required String address,
    required Network network,
    @Default(0) int sats,
    @Default('') String label,
    @Default('') String message,
    @Default('') String lightning,
    @Default('') String pj,
    @Default('') String pjos,
  }) = Bip21;

  const factory Satoshifier.psbt({required String psbt}) = Psbt;

  const factory Satoshifier.watchOnlyXpub({
    required ExtendedPubkey extendedPubkey,
  }) = WatchOnlyXpub;

  const factory Satoshifier.watchOnlyDescriptor({
    required Descriptor descriptor,
  }) = WatchOnlyDescriptor;

  const factory Satoshifier.lnurl({required String address}) = Lnurl;

  const Satoshifier._();

  bool isType<T>() => this is T;

  static Future<Satoshifier> parse(String data) async {
    return await Registry.parse(data);
  }

  static Future<Satoshifier?> tryParse(String data) async {
    return await Registry.tryParse(data);
  }
}
