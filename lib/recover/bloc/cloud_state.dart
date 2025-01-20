part of 'cloud_cubit.dart';

@freezed
class CloudState with _$CloudState {
  factory CloudState({
    @Default(false) bool loading,
    @Default('') String backupFolderId,
    @Default({}) Map<String, File> availableBackups,
    @Default(('', '')) (String, String) selectedBackup,
    DateTime? lastFetchTime,
    @Default(Duration(minutes: 5)) Duration cacheValidityDuration,
    @Default('') String toast,
    @Default('') String error,
  }) = _CloudState;
  const CloudState._();
  bool get isCacheValid {
    if (lastFetchTime == null) return false;
    return DateTime.now().difference(lastFetchTime!) < cacheValidityDuration;
  }
}
