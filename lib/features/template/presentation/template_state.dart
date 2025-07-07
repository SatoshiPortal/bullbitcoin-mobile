import 'package:bb_mobile/features/template/domain/ip_address_entity.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'template_state.freezed.dart';

enum Redirection { none, toSomewhereElse }

@freezed
sealed class TemplateState with _$TemplateState {
  const factory TemplateState({
    @Default(Redirection.none) Redirection redirection,
    @Default(false) bool isLoading,
    Exception? error,
    IpAddressEntity? ipAddress,
  }) = _TemplateState;
}
