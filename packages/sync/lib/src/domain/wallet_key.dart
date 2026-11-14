import 'package:primitives/primitives.dart';

/// Stable identity. Engine, connection settings and endpoints are not identity.
final class WalletKey {
  final String id;
  final Network network;

  WalletKey({required this.id, required this.network}) {
    if (id.isEmpty) throw ArgumentError('Wallet id must not be empty');
  }

  @override
  bool operator ==(Object other) =>
      other is WalletKey && other.id == id && other.network == network;

  @override
  int get hashCode => Object.hash(id, network);
}
