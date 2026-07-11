import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:bb_mobile/features/sp/ui/widgets/sp_backend_config_form.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpSetupPage extends StatelessWidget {
  const SpSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.spSetupTitle)),
      body: BlocConsumer<SpSetupCubit, SpSetupState>(
        listenWhen: (prev, curr) => !prev.created && curr.created,
        listener: (context, state) => Navigator.of(context).pop(),
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
                    blindbitFieldKey: ValueKey('blindbit_${state.network.name}'),
                    electrumFieldKey: ValueKey('electrum_${state.network.name}'),
                    onFetchDefaults: cubit.fetchRegtestDefaults,
                    onBlindbitChanged: cubit.setBlindbitUrl,
                    onTestBlindbit: cubit.testBlindbit,
                    onElectrumChanged: cubit.setElectrumUrl,
                    onTestElectrum: cubit.testElectrum,
                    networkField: DropdownButtonFormField<SpNetwork>(
                      key: ValueKey('network_${state.network.name}'),
                      initialValue: state.network,
                      decoration: InputDecoration(
                        labelText: context.loc.spNetworkLabel,
                      ),
                      items: SpNetwork.values
                          .map(
                            (n) => DropdownMenuItem(
                              value: n,
                              child: Text(n.name),
                            ),
                          )
                          .toList(),
                      onChanged: (n) {
                        if (n != null) cubit.setNetwork(n);
                      },
                    ),
                    submit: BBButton.big(
                      onPressed: cubit.create,
                      label: context.loc.spCreateButton,
                      bgColor: context.appColors.primary,
                      textColor: context.appColors.onPrimary,
                      disabled: !state.canCreate,
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
