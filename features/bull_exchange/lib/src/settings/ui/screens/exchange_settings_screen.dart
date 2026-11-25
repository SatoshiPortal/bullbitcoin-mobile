import 'dart:async';

import 'package:bull_ui/bull_ui.dart' show BullSettingsEntryItem;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../exchange_l10n.dart';
import '../../../exchange_landing_navigation.dart';
import '../exchange_settings_route.dart';
import '../widgets/not_logged_in_bottom_sheet.dart';

class ExchangeSettingsScreen extends StatefulWidget {
  const ExchangeSettingsScreen({
    required this.websiteOnly,
    required this.onOpenRecipients,
    required this.onOpenTransactions,
    required this.onOpenDefaultWallets,
    required this.onOpenExchange,
    required this.isLoggedIn,
    required this.sessionChanges,
    required this.title,
    required this.signedOutMessage,
    required this.buildAccountActions,
    super.key,
  });

  /// iOS without superuser: only the account actions are shown.
  final bool websiteOnly;
  final VoidCallback onOpenRecipients;
  final VoidCallback onOpenTransactions;
  final VoidCallback onOpenDefaultWallets;
  final VoidCallback onOpenExchange;
  final bool Function() isLoggedIn;
  final Stream<bool> Function() sessionChanges;
  final String Function(BuildContext) title;
  final String Function(BuildContext) signedOutMessage;
  final Widget Function(bool showDeleteAccount) buildAccountActions;

  @override
  State<ExchangeSettingsScreen> createState() => _ExchangeSettingsScreenState();
}

class _ExchangeSettingsScreenState extends State<ExchangeSettingsScreen> {
  late bool _loggedIn;
  StreamSubscription<bool>? _session;

  @override
  void initState() {
    super.initState();
    _loggedIn = widget.isLoggedIn();
    _session = widget.sessionChanges().listen((isLoggedIn) {
      if (!mounted || _loggedIn == isLoggedIn) return;
      final signedOut = _loggedIn && !isLoggedIn;
      setState(() => _loggedIn = isLoggedIn);
      if (signedOut) BullExchangeNavigation.goToLanding(context);
    });
  }

  @override
  void dispose() {
    _session?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final isLoggedIn = _loggedIn;
        void openWhenLoggedIn(VoidCallback open) {
          if (isLoggedIn) {
            open();
          } else {
            NotLoggedInBottomSheet.show(
              context,
              message: widget.signedOutMessage(context),
              onSignIn: widget.onOpenExchange,
            );
          }
        }

        void pushWhenLoggedIn(ExchangeSettingsRoute route) =>
            openWhenLoggedIn(() => context.pushNamed(route.name));

        return Scaffold(
          appBar: AppBar(
            // A route nested under the settings route, whose page is always
            // under it: the router's own pop is this screen's Back.
            automaticallyImplyLeading: true,
            title: Text(widget.title(context)),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (!widget.websiteOnly) ...[
                      BullSettingsEntryItem(
                        icon: Icons.account_circle,
                        title:
                            context.loc.exchangeSettingsAccountInformationTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.accountInfo),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.security,
                        title:
                            context.loc.exchangeSettingsSecuritySettingsTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.security),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.people,
                        title: context.loc.exchangeSettingsRecipientsTitle,
                        onTap: () => openWhenLoggedIn(widget.onOpenRecipients),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.history,
                        title: context.loc.exchangeSettingsTransactionsTitle,
                        onTap: () =>
                            openWhenLoggedIn(widget.onOpenTransactions),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.currency_bitcoin,
                        title: context.loc.exchangeBitcoinWalletsTitle,
                        onTap: () =>
                            openWhenLoggedIn(widget.onOpenDefaultWallets),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.settings,
                        title: context.loc.settingsAppSettingsTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.preferences),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.upload_file,
                        title: context.loc.exchangeFileUploadTitle,
                        onTap: () => pushWhenLoggedIn(
                          ExchangeSettingsRoute.secureFileUpload,
                        ),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.bar_chart,
                        title: context.loc.exchangeStatisticsTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.statistics),
                      ),
                      BullSettingsEntryItem(
                        icon: Icons.share,
                        title: context.loc.exchangeSettingsReferralsTitle,
                        onTap: () =>
                            pushWhenLoggedIn(ExchangeSettingsRoute.referrals),
                      ),
                      if (!isLoggedIn)
                        BullSettingsEntryItem(
                          icon: Icons.login,
                          title: context.loc.exchangeSettingsLogInTitle,
                          onTap: () =>
                              BullExchangeNavigation.goToLanding(context),
                        ),
                    ],
                    widget.buildAccountActions(widget.websiteOnly),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
