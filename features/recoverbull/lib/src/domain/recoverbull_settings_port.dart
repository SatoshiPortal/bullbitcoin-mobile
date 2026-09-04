import 'entities/recoverbull_tor_settings.dart';

abstract interface class RecoverBullSettingsPort {
  Future<RecoverBullTorSettings> fetch();
}
