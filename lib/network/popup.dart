import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class NetworkPopup extends StatelessWidget {
  const NetworkPopup({super.key});

  static Future openPopUp(BuildContext context) {
    return showBBBottomSheet(
      context: context,
      child: const NetworkPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const NetworkScreen();
  }
}

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final networks = context.select((NetworkCubit _) => _.state.networks);
    if (networks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(8),
          BBHeader.popUpCenteredText(
            text: 'Electrum Server',
            isLeft: true,
            onBack: () {
              context.read<NetworkCubit>().resetTempNetwork();
              context.pop();
            },
          ),
          const NetworkStatus(),
          const Gap(24),
          const SelectNetworkSegment(),
          const Gap(16),
          const NetworkConfigFields(),
          const Gap(80),
        ],
      ),
    );
  }
}

class NetworkStatus extends StatelessWidget {
  const NetworkStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final networkConnected = context.select((NetworkCubit x) => x.state.networkConnected);
    final errLoadingNetwork = context.select((NetworkCubit x) => x.state.errLoadingNetworks);
    final isTestnet = context.select((NetworkCubit x) => x.state.testnet);
    final network =
        context.select((NetworkCubit x) => x.state.getNetwork()?.getNetworkUrl(isTestnet) ?? '');

    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: networkConnected ? Colors.green : context.colour.error,
              ),
            ),
            const Gap(8),
            BBText.body(network),
          ],
        ),
        if (errLoadingNetwork.isNotEmpty) ...[
          const Gap(8),
          BBText.errorSmall(errLoadingNetwork),
        ],
      ],
    );
  }
}

class SelectNetworkSegment extends StatelessWidget {
  const SelectNetworkSegment({super.key});

  @override
  Widget build(BuildContext context) {
    final tempSelected = context.select((NetworkCubit x) => x.state.tempNetwork);
    final network = context.select((NetworkCubit x) => x.state.selectedNetwork);

    final selected = tempSelected ?? network;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SegmentButton(
          index: 0,
          isSelected: selected == ElectrumTypes.blockstream,
          text: 'Blockstream',
        ),
        _SegmentButton(
          index: 1,
          isSelected: selected == ElectrumTypes.bullbitcoin,
          text: 'Bull Bitcoin',
        ),
        _SegmentButton(
          index: 2,
          isSelected: selected == ElectrumTypes.custom,
          text: 'Custom',
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.index,
    required this.isSelected,
    required this.text,
  });

  final int index;
  final bool isSelected;
  final String text;

  @override
  Widget build(BuildContext context) {
    final selectedBGColour = context.colour.surface.withOpacity(0.3);
    final unselectedBGColour = context.colour.surface.withOpacity(0.1);

    return Expanded(
      child: InkWell(
        onTap: () {
          final network = context.read<NetworkCubit>().state.networkFromString(text);
          if (network == null) return;
          context.read<NetworkCubit>().networkTypeTempChanged(network);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? selectedBGColour : unselectedBGColour,
            borderRadius: BorderRadius.only(
              topLeft: index == 0 ? const Radius.circular(8) : Radius.zero,
              topRight: index == 2 ? const Radius.circular(8) : Radius.zero,
            ),
          ),
          child: Column(
            children: [
              const Gap(8),
              BBText.bodySmall(text, removeColourOpacity: true),
              Gap(isSelected ? 7 : 8),
              Container(
                height: isSelected ? 2 : 1,
                color: isSelected ? context.colour.primary : context.colour.surface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NetworkConfigFields extends StatelessWidget {
  const NetworkConfigFields({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fieldWidth = MediaQuery.of(context).size.width * 0.7;

    final network = context.select((NetworkCubit x) => x.state.getTempOrSelectedNetwork());
    if (network == null) return const SizedBox.shrink();

    final tempNetworkDetails = context.select((NetworkCubit x) => x.state.tempNetworkDetails);
    if (tempNetworkDetails == null) return const SizedBox.shrink();

    final type = network.type;

    final err = context.select((NetworkCubit x) => x.state.errLoadingNetworks);
    final loading = context.select((NetworkCubit x) => x.state.loadingNetworks);

    final showButton = context.select((NetworkCubit x) => x.state.showConfirmButton());

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(16),
          const BBText.title('    Mainnet'),
          const Gap(4),
          SizedBox(
            width: fieldWidth,
            child: BBTextInput.big(
              onChanged: (t) {
                context.read<NetworkCubit>().updateTempMainnet(t);
              },
              value: tempNetworkDetails.mainnet,
              disabled: type != ElectrumTypes.custom,
            ),
          ),
          const Gap(16),
          const BBText.title('    Testnet'),
          const Gap(4),
          SizedBox(
            width: fieldWidth,
            child: BBTextInput.big(
              onChanged: (t) {
                context.read<NetworkCubit>().updateTempTestnet(t);
              },
              value: tempNetworkDetails.testnet,
              disabled: type != ElectrumTypes.custom,
            ),
          ),
          const Gap(16),
          Row(
            children: [
              const BBText.body('Validate domain'),
              const Spacer(),
              IgnorePointer(
                ignoring: type != ElectrumTypes.custom,
                child: BBSwitch(
                  value: tempNetworkDetails.validateDomain,
                  onChanged: (e) {
                    context.read<NetworkCubit>().updateTempValidateDomain(e);
                  },
                ),
              ),
            ],
          ),
          const Gap(8),
          BBButton.textWithRightArrow(
            label: 'Advanced Options',
            onPressed: () {
              ElectrumAdvancedOptions.openPopUp(context);
            },
          ),
          const Gap(40),
          if (err.isNotEmpty) ...[
            BBText.error(err),
            const Gap(8),
          ],
          if (showButton.err != null) ...[
            BBText.error(showButton.err!),
            const Gap(8),
          ],
          Center(
            child: BBButton.big(
              loading: loading,
              loadingText: 'Connecting...',
              disabled: !showButton.show,
              onPressed: () async {
                FocusScope.of(context).requestFocus(FocusNode());

                if (type == ElectrumTypes.custom) {
                  await PrivacyNoticePopUp.openPopUp(context);
                  return;
                }

                context.read<NetworkCubit>().networkConfigsSaveClicked();
                await Future.delayed(const Duration(milliseconds: 500));
                final err = context.read<NetworkCubit>().state.errLoadingNetworks;
                if (err.isEmpty) context.pop();
              },
              label: 'SAVE',
              filled: true,
            ),
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

class PrivacyNoticePopUp extends StatelessWidget {
  const PrivacyNoticePopUp({super.key});

  static Future openPopUp(BuildContext context) {
    return showBBBottomSheet(
      context: context,
      child: const PrivacyNoticePopUp(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBHeader.popUpCenteredText(
            text: 'Privacy Notice',
            isLeft: true,
            onBack: () {
              context.pop();
            },
          ),
          const Gap(16),
          const BBText.body('''
    Privacy Notice: Using your own node ensures that no third party can link your IP address, with your transactions. 
    
    However, if you view transactions via mempool by clicking your Transaction ID or Recipient Bitcoin Address in the Transaction Details page, this information will be known to BullBitcoin.'''),
          const Gap(40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              BBButton.text(
                label: 'CANCEL',
                onPressed: () {
                  context.pop();
                },
              ),
              SizedBox(
                width: 150,
                child: BBButton.big(
                  label: 'SAVE',
                  filled: true,
                  onPressed: () async {
                    context.read<NetworkCubit>().networkConfigsSaveClicked();
                    await Future.delayed(const Duration(milliseconds: 500));
                    final err = context.read<NetworkCubit>().state.errLoadingNetworks;
                    if (err.isNotEmpty)
                      context.pop();
                    else
                      context
                        ..pop()
                        ..pop();
                  },
                ),
              ),
            ],
          ),
          const Gap(40),
        ],
      ),
    );
  }
}

class ElectrumAdvancedOptions extends StatelessWidget {
  const ElectrumAdvancedOptions({super.key});

  static Future openPopUp(
    BuildContext context,
  ) {
    return showBBBottomSheet(
      context: context,
      child: const ElectrumAdvancedOptions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldWidth = MediaQuery.of(context).size.width * 0.7;

    final sg = context.select((NetworkCubit x) => x.state.tempNetworkDetails?.stopGap);
    final r = context.select((NetworkCubit x) => x.state.tempNetworkDetails?.retry);
    final t = context.select((NetworkCubit x) => x.state.tempNetworkDetails?.timeout);

    final showButton = context.select((NetworkCubit x) => x.state.showConfirmButton());

    return Padding(
      padding: const EdgeInsets.only(left: 24.0, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBHeader.popUpCenteredText(
            text: 'Electrum Options',
            isLeft: true,
            onBack: () {
              context.pop();
            },
          ),
          const Gap(24),
          const BBText.title('    Stop gap'),
          const Gap(4),
          SizedBox(
            width: fieldWidth,
            child: BBTextInput.big(
              onlyNumbers: true,
              onChanged: (t) {
                final sg = int.tryParse(t);
                if (sg == null) {
                  context.read<NetworkCubit>().updateTempStopGap(0);
                  return;
                }
                context.read<NetworkCubit>().updateTempStopGap(sg);
              },
              value: sg.toString(),
            ),
          ),
          const Gap(16),
          const BBText.title('    Retry'),
          const Gap(4),
          SizedBox(
            width: fieldWidth,
            child: BBTextInput.big(
              onlyNumbers: true,
              onChanged: (t) {
                final r = int.tryParse(t);
                if (r == null) {
                  context.read<NetworkCubit>().updateTempRetry(0);
                  return;
                }
                context.read<NetworkCubit>().updateTempRetry(r);
              },
              value: r.toString(),
            ),
          ),
          const Gap(16),
          const BBText.title('    Timeout'),
          const Gap(4),
          SizedBox(
            width: fieldWidth,
            child: BBTextInput.big(
              onlyNumbers: true,
              onChanged: (t) {
                final tt = int.tryParse(t);
                if (tt == null) {
                  context.read<NetworkCubit>().updateTempTimeout(0);
                  return;
                }
                context.read<NetworkCubit>().updateTempTimeout(tt);
              },
              value: t.toString(),
            ),
          ),
          const Gap(32),
          if (showButton.err != null) ...[
            BBText.errorSmall(showButton.err!),
            const Gap(8),
          ],
          Center(
            child: BBButton.big(
              label: 'Confirm',
              filled: true,
              disabled: !showButton.show,
              onPressed: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                context.pop();
              },
            ),
          ),
          const Gap(48),
        ],
      ),
    );
  }
}
