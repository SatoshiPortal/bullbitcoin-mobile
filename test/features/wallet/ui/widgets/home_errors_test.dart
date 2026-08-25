import 'package:bb_mobile/features/wallet/domain/entity/warning.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_errors.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('describes a Tor action as an unreachable SOCKS5 proxy', (
    tester,
  ) async {
    final warning = WalletWarning(
      title: 'Bitcoin electrum server failure',
      description: 'Click to configure electrum server settings',
      action: WalletWarningAction.torSettings,
      type: WarningType.error,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Column(
            children: [
              Text(homeWarningTitle(context, warning)),
              Text(homeWarningDescription(context, warning)),
            ],
          ),
        ),
      ),
    );

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.torSettingsExternalProxyUnavailable), findsOneWidget);
    expect(
      find.text(l10n.torSettingsExternalProxyUnavailableDescription),
      findsOneWidget,
    );
    expect(find.text('Bitcoin electrum server failure'), findsNothing);
  });
}
