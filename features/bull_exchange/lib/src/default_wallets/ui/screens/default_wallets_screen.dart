import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/default_wallets/ui/widgets/default_wallets_editor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullTopBar;

import '../../default_wallets_payout_fields.dart';

class DefaultWalletsScreen extends StatelessWidget {
  final Exchange exchange;
  final DefaultWalletsPayoutFields payoutFields;

  const DefaultWalletsScreen({
    required this.exchange,
    required this.payoutFields,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.exchangeBitcoinWalletsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: DefaultWalletsEditor(
        exchange: exchange,
        payoutFields: payoutFields,
      ),
    );
  }
}
