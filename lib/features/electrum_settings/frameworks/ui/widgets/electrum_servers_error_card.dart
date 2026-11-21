import 'package:bull_ui/bull_ui.dart' show BullButton, BullButtonSize;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:electrum/electrum.dart';
import 'package:bb_mobile/features/electrum_settings/presentation/electrum_settings_failure_l10n.dart';
import 'package:bb_mobile/features/tor_settings/public/tor_settings_facade.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullInfoCard, Gap;

class ElectrumServersErrorCard extends StatelessWidget {
  const ElectrumServersErrorCard({required this.failure, super.key});

  final ElectrumServersFailure failure;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BullInfoCard(
        description: failure.toTranslated(context),
        tagColor: context.appColors.error,
        bgColor: context.appColors.errorContainer,
      ),
      if (failure is ElectrumServersExternalTorProxyUnavailableFailure) ...[
        const Gap(4),
        BullButton.secondary(
          label: context.loc.electrumOpenTorSettings,
          onPressed: () =>
              context.pushNamed(const TorSettingsFacade().settingsRouteName),
          size: BullButtonSize.small,
          compact: true,
        ),
      ],
    ],
  );
}
