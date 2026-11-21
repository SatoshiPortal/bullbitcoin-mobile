import 'package:bull_ui/bull_ui.dart'
    show BullThemeX, BullButton, BullButtonSize;

import '../../../network_l10n.dart';

import 'package:electrum/electrum.dart';

import '../../presentation/electrum_settings_failure_l10n.dart';
import '../../../tor_settings/ui/tor_settings_router.dart';

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
        tagColor: context.bull.error,
        bgColor: context.bull.errorContainer,
      ),
      if (failure is ElectrumServersExternalTorProxyUnavailableFailure) ...[
        const Gap(4),
        BullButton.secondary(
          label: context.loc.electrumOpenTorSettings,
          onPressed: () => context.pushNamed(TorSettingsRoute.torSettings.name),
          size: BullButtonSize.small,
          compact: true,
        ),
      ],
    ],
  );
}
