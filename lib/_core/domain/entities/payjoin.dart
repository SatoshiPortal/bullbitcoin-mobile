import 'package:freezed_annotation/freezed_annotation.dart';

part 'payjoin.freezed.dart';

@freezed
sealed class Payjoin with _$Payjoin {
  const factory Payjoin.receive() = PayjoinReceive;
  const factory Payjoin.send() = PayjoinSend;
}
