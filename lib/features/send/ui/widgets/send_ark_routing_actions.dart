import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show NetworkX;
import 'package:bull_ark/ark_ui.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../presentation/bloc/send_cubit.dart';
import '../../presentation/bloc/send_state.dart';
import '../../presentation/send_ark_cubit.dart';

class SendArkRoutingActions extends StatefulWidget {
  final Widget fallback;
  const SendArkRoutingActions({super.key, required this.fallback});
  @override
  State<SendArkRoutingActions> createState() => _SendArkRoutingActionsState();
}

class _SendArkRoutingActionsState extends State<SendArkRoutingActions> {
  SendArkCubit? _ark;
  @override
  void initState() {
    super.initState();
    _ark = context.read<SendArkCubit?>();
    _resolve(context.read<SendCubit>().state);
  }

  void _resolve(SendState state) {
    _ark?.resolve(
      input: state.recipientDrafts.isEmpty
          ? state.copiedRawPaymentRequest
          : state.recipientDrafts.first.address,
      network: state.selectedWallet?.network.shared,
      coinControl:
          state.usesSelectedInputsOnly || state.selectedUtxos.isNotEmpty,
      sweep: state.isSweep,
      silentPayments: context.read<SendCubit>().isSpMode,
      multipleRecipients: state.hasMultipleRecipients,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ark = _ark;
    if (ark == null) return widget.fallback;
    return BlocListener<SendCubit, SendState>(
      listenWhen: (previous, current) =>
          previous.recipientDrafts != current.recipientDrafts ||
          previous.copiedRawPaymentRequest != current.copiedRawPaymentRequest ||
          previous.selectedWallet != current.selectedWallet ||
          previous.selectedUtxos != current.selectedUtxos ||
          previous.selectedInputOutpoints != current.selectedInputOutpoints ||
          previous.sweepOutpoints != current.sweepOutpoints,
      listener: (_, state) => _resolve(state),
      child: BlocBuilder<SendArkCubit, SendArkState>(
        bloc: ark,
        builder: (context, state) => switch (state) {
          SendArkReady(:final request) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final account in request.accounts)
                ArkSendEntryButton(
                  account: account,
                  onPressed: () => ArkNavigation.send(
                    context,
                    account,
                    destination: request.destination,
                  ),
                ),
            ],
          ),
          SendArkUnavailable() => BullInfoBar(
            message: arkLocalizationsOf(context).nativeUnavailable,
            tone: BullInfoTone.warning,
          ),
          SendArkLoading() => BullText(
            arkLocalizationsOf(context).loading,
            style: null,
          ),
          SendArkHidden() => widget.fallback,
        },
      ),
    );
  }
}
