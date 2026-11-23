import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:bb_mobile/features/sp/ui/sp_router.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_backend_config_form.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_scan_start_selector.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, Gap, BullTypographyX;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SpSetupScreen extends StatelessWidget {
  const SpSetupScreen({super.key, required this.successRedirectPath});

  final String successRedirectPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.spSetupTitle)),
      body: BlocConsumer<SpSetupCubit, SpSetupState>(
        listenWhen: (prev, curr) => !prev.created && curr.created,
        listener: (context, state) {
          if (state.scanStart != SpScanStart.earlierBlock) {
            context.go(successRedirectPath);
            return;
          }
          // An imported wallet still has to pick a start height, so it lands on
          // the scan screen. Go to the wallet first and push the scan screen on
          // top: the scan screen's back button and its post-scan pop both need
          // the wallet underneath them. Hold the router, since `go` takes this
          // listener's context out of the tree.
          final router = GoRouter.of(context);
          router.go(SpRoute.spWalletDetail.path);
          unawaited(router.push(SpRoute.spScan.path));
        },
        builder: (context, state) {
          final cubit = context.read<SpSetupCubit>();
          return Column(
            children: [
              if (state.isCreating || state.isFetchingDefaults)
                LinearProgressIndicator(
                  backgroundColor: context.appColors.surface,
                  color: context.appColors.primary,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SpBackendConfigForm<SpSetupState>(
                    state: state,
                    isBusy: state.isCreating,
                    onFetchDefaults: cubit.fetchRegtestDefaults,
                    onBlindbitChanged: cubit.setBlindbitUrl,
                    onTestBlindbit: cubit.testBlindbit,
                    onElectrumChanged: cubit.setElectrumUrl,
                    onTestElectrum: cubit.testElectrum,
                    networkField: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.loc.spNetworkLabel,
                          style: context.bullType.body,
                        ),
                        const Gap(4),
                        Text(state.network.name),
                      ],
                    ),
                    extraFields: SpScanStartSelector(
                      scanStart: state.scanStart,
                      onChanged: cubit.setScanStart,
                      isBusy: state.isCreating,
                    ),
                    submit: BullButton.primary(
                      onPressed: (!state.canCreate) ? null : cubit.create,
                      label: context.loc.spCreateButton,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
