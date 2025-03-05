import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin.freezed.dart';

@freezed
sealed class Payjoin with _$Payjoin {
  const factory Payjoin.receiver({
    required String id,
    required String walletId,
    String? broadcastedTxId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = ReceivePayjoin;
  const factory Payjoin.sender({
    required String uri,
    required String walletId,
    String? broadcastedTxId,
    @Default(false) bool isExpired,
    @Default(false) bool isCompleted,
  }) = SendPayjoin;
  const Payjoin._();

  String get id => when(
        receiver: (id, _, __, ___, ____) => id,
        sender: (uri, _, __, ___, ____) => uri,
      );
}
