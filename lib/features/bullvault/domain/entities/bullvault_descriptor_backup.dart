import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// A private BIP138 artifact: the vault descriptor it carries, and the accounts
/// that can open it.
///
/// [recipients] are complete account identities, normalised and deduplicated,
/// in the order the descriptor names them. Encoding knows all of them; decoding
/// knows only the account whose key opened the artifact, because a recipient
/// mask is indistinguishable from the decoys beside it.
///
/// [lookupTokens] is the canonical set the descriptor record API requires:
/// strictly ascending, so it is sorted and duplicate free at once. It is the
/// same set [recipients] derives, in the order the wire wants rather than the
/// order the descriptor gives.
final class BullVaultDescriptorBackup {
  /// BIP138 allows five recipient masks, decoys included.
  static const maxRecipients = 5;

  final String descriptor;
  final Network network;
  final Uint8List bytes;
  final List<String> recipients;
  final List<String> lookupTokens;

  BullVaultDescriptorBackup({
    required this.descriptor,
    required this.network,
    required Uint8List bytes,
    required Iterable<String> recipients,
    required Iterable<String> lookupTokens,
  }) : bytes = bytes.asUnmodifiableView(),
       recipients = List.unmodifiable(recipients),
       lookupTokens = List.unmodifiable(lookupTokens) {
    if (descriptor.isEmpty ||
        !network.isBitcoin ||
        bytes.isEmpty ||
        this.recipients.isEmpty ||
        this.recipients.length > maxRecipients ||
        this.recipients.toSet().length != this.recipients.length ||
        this.lookupTokens.length != this.recipients.length) {
      throw ArgumentError('Invalid private descriptor backup');
    }
    for (var index = 0; index < this.lookupTokens.length; index++) {
      final token = this.lookupTokens[index];
      if (!_tokenPattern.hasMatch(token) ||
          (index > 0 && token.compareTo(this.lookupTokens[index - 1]) <= 0)) {
        throw ArgumentError('Invalid private descriptor lookup tokens');
      }
    }
  }
}

final _tokenPattern = RegExp(r'^[0-9a-f]{64}$');
