import 'package:bull_ui/bull_ui.dart';

/// Common copy supplied by the embedding shell in its active locale.
final class RecoverBullUiLabels {
  final String oopsSomethingWentWrong;
  final String statusScreenTryAgain;
  final String statusScreenContinue;
  final String copyDialogButton;
  final String closeDialogButton;
  final String walletSetupErrorTryAgain;
  final String torSettingsTitle;
  final String torSettingsModeSnowflake;
  final String Function(String transport) torSettingsActiveTransport;
  final String torSettingsModeAutomaticDescription;
  final String torSettingsStatusCensored;
  final String torSettingsModeSnowflakeDescription;
  final String backupWalletHowToDecideBackupModalTitle;
  final String torSettingsModeDirectDescription;
  final String torSettingsDescConnected;
  final String torSettingsExternalProxyUnavailableDescription;
  final String torSettingsDescCensored;
  final String backupWalletHowToDecide;
  final String torSettingsDescDisconnected;
  final String copyDialogCopied;

  const RecoverBullUiLabels({
    required this.oopsSomethingWentWrong,
    required this.statusScreenTryAgain,
    required this.statusScreenContinue,
    required this.copyDialogButton,
    required this.closeDialogButton,
    required this.walletSetupErrorTryAgain,
    required this.torSettingsTitle,
    required this.torSettingsModeSnowflake,
    required this.torSettingsActiveTransport,
    required this.torSettingsModeAutomaticDescription,
    required this.torSettingsStatusCensored,
    required this.torSettingsModeSnowflakeDescription,
    required this.backupWalletHowToDecideBackupModalTitle,
    required this.torSettingsModeDirectDescription,
    required this.torSettingsDescConnected,
    required this.torSettingsExternalProxyUnavailableDescription,
    required this.torSettingsDescCensored,
    required this.backupWalletHowToDecide,
    required this.torSettingsDescDisconnected,
    required this.copyDialogCopied,
  });
}

class RecoverBullUiLabelsScope extends InheritedWidget {
  final RecoverBullUiLabels labels;

  const RecoverBullUiLabelsScope({
    super.key,
    required this.labels,
    required super.child,
  });

  static RecoverBullUiLabels of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RecoverBullUiLabelsScope>();
    if (scope == null) {
      throw StateError(
        'The embedding shell must provide RecoverBullUiLabelsScope',
      );
    }
    return scope.labels;
  }

  @override
  bool updateShouldNotify(RecoverBullUiLabelsScope oldWidget) =>
      labels != oldWidget.labels;
}

extension RecoverBullUiLabelsContext on BuildContext {
  RecoverBullUiLabels get recoverBullLabels =>
      RecoverBullUiLabelsScope.of(this);
}
