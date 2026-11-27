import 'package:exchange/exchange.dart';

import '../domain/entities/account_info.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_info_state.freezed.dart';

@freezed
abstract class AccountInfoState with _$AccountInfoState {
  const factory AccountInfoState({
    AccountInfo? accountInfo,
    @Default(false) bool isLoading,
    ExchangeFailure? failure,
  }) = _AccountInfoState;
}
