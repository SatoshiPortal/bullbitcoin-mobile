import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings.dart';

enum GetPaidSettingsStatus { initial, loading, loaded, failure }

final class GetPaidSettingsState {
  final GetPaidSettingsStatus status;
  final GetPaidSettings? settings;
  final bool saving;
  final bool backingUp;
  final bool deleting;

  const GetPaidSettingsState({
    this.status = GetPaidSettingsStatus.initial,
    this.settings,
    this.saving = false,
    this.backingUp = false,
    this.deleting = false,
  });

  bool get busy => saving || backingUp || deleting;

  GetPaidSettingsState copyWith({
    GetPaidSettingsStatus? status,
    GetPaidSettings? settings,
    bool? saving,
    bool? backingUp,
    bool? deleting,
  }) => GetPaidSettingsState(
    status: status ?? this.status,
    settings: settings ?? this.settings,
    saving: saving ?? this.saving,
    backingUp: backingUp ?? this.backingUp,
    deleting: deleting ?? this.deleting,
  );
}
