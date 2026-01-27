import 'package:meta/meta.dart';

@immutable
sealed class SecretConsumer {
  const SecretConsumer();
}

@immutable
class WalletConsumer extends SecretConsumer {
  final String walletId;

  const WalletConsumer(this.walletId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletConsumer &&
          runtimeType == other.runtimeType &&
          walletId == other.walletId;

  @override
  int get hashCode => walletId.hashCode;

  @override
  String toString() => 'WalletConsumer($walletId)';
}

@immutable
class Bip85Consumer extends SecretConsumer {
  final String bip85Path;

  const Bip85Consumer(this.bip85Path);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bip85Consumer &&
          runtimeType == other.runtimeType &&
          bip85Path == other.bip85Path;

  @override
  int get hashCode => bip85Path.hashCode;

  @override
  String toString() => 'Bip85Consumer($bip85Path)';
}
