import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter/widgets.dart';

RecoverBullUiLabels testUiLabels([BuildContext? context]) {
  final french =
      context != null && Localizations.localeOf(context).languageCode == 'fr';
  return RecoverBullUiLabels(
    oopsSomethingWentWrong: french
        ? "Oups ! Une erreur s'est produite"
        : "Oops! Something went wrong",
    statusScreenTryAgain: french ? "Réessayer" : "Try Again",
    statusScreenContinue: french ? "Continuer" : "Continue",
    copyDialogButton: french ? "Copier" : "Copy",
    closeDialogButton: french ? "Fermer" : "Close",
    walletSetupErrorTryAgain: french
        ? "Une erreur s'est produite lors de la configuration de votre portefeuille. Veuillez réessayer."
        : "Something went wrong setting up your wallet. Please try again.",
    torSettingsTitle: french ? "Paramètres Tor" : "Tor Settings",
    torSettingsModeSnowflake: french ? "Snowflake" : "Snowflake",
    torSettingsActiveTransport: (transport) => french
        ? "Transport actif : $transport"
        : "Active transport: $transport",
    torSettingsModeAutomaticDescription: french
        ? "Essaie d'abord une connexion Tor directe, puis Snowflake si le réseau semble bloquer Tor."
        : "Tries a direct Tor connection first and uses Snowflake if the network appears to block Tor.",
    torSettingsStatusCensored: french
        ? "Connexion semble filtrée"
        : "Connection appears filtered",
    torSettingsModeSnowflakeDescription: french
        ? "Utilise les proxys bénévoles Snowflake pour joindre Tor depuis un réseau filtré."
        : "Uses volunteer Snowflake proxies to reach Tor from a filtered network.",
    backupWalletHowToDecideBackupModalTitle: french
        ? "Comment décider"
        : "How to decide",
    torSettingsModeDirectDescription: french
        ? "Se connecte directement au réseau Tor, sans transport enfichable."
        : "Connects directly to the Tor network without a pluggable transport.",
    torSettingsDescConnected: french
        ? "Le proxy Tor est actif et prêt"
        : "Tor proxy is running and ready",
    torSettingsExternalProxyUnavailableDescription: french
        ? "Bull n’a pas pu se connecter au proxy SOCKS5 configuré."
        : "Bull could not connect to the configured SOCKS5 proxy.",
    torSettingsDescCensored: french
        ? "Tor n'a pas pu joindre le réseau. Cela indique souvent une connexion filtrée."
        : "Tor could not reach the network. This often means the connection is being filtered.",
    backupWalletHowToDecide: french ? "Comment décider ?" : "How to decide?",
    torSettingsDescDisconnected: french
        ? "Le proxy Tor n'est pas actif"
        : "Tor proxy is not running",
    copyDialogCopied: french ? "Copié" : "Copied",
  );
}

Widget withTestUiLabels(BuildContext context, Widget child) =>
    RecoverBullUiLabelsScope(labels: testUiLabels(context), child: child);
