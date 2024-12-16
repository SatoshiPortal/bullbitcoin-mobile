import 'package:bb_mobile/_model/network.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network/bloc/state.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class _NetworkSelector extends Cubit<bool> {
  _NetworkSelector({bool isLiq = false}) : super(isLiq);
  void selectNetwork(bool isLiquid) => emit(isLiquid);
}

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
    return BlocListener<NetworkCubit, NetworkState>(
      listenWhen: (previous, current) =>
          previous.networkConnected == false &&
          current.networkConnected == true &&
          current.errLoadingNetworks.isEmpty,
      listener: (context, state) async {
        await Future.delayed(const Duration(seconds: 1));

        if (!context.mounted) return;
        context.pop();
      },
      child: BlocProvider.value(
        value: _NetworkSelector(),
        child: const NetworkScreen(),
      ),
    );
  }
}

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final networks = context.select((NetworkCubit _) => _.state.networks);
    if (networks.isEmpty) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(8),
          _NetowrkHeader(),
          NetworkStatus(),
          Gap(24),
          SelectNetworkSegment(),
          Gap(16),
          NetworkConfigFields(),
          Gap(80),
        ],
      ),
    );
  }
}

class _NetowrkHeader extends StatelessWidget {
  const _NetowrkHeader();

  @override
  Widget build(BuildContext context) {
    final isLiq = context.select((_NetworkSelector _) => _.state);
    final networkStr = isLiq ? 'Liquid' : 'Bitcoin';
    final changeStr = 'Configure ${isLiq ? 'Bitcoin' : 'Liquid'} Network';

    return BBHeader.popUpCenteredText(
      text: '', //networkStr + ' Network',
      leftChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText.titleLarge(
            '$networkStr Network',
            isBold: true,
          ),
          BBButton.text(
            fontSize: 11,
            label: changeStr,
            onPressed: () {
              context.read<_NetworkSelector>().selectNetwork(!isLiq);
            },
          ),
        ],
      ),
      isLeft: true,
      onBack: () {
        context.read<NetworkCubit>().resetTempNetwork();
        context.pop();
      },
    );
  }
}

class NetworkStatus extends StatelessWidget {
  const NetworkStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final isLiq = context.select((_NetworkSelector _) => _.state);
    final networkConnected =
        context.select((NetworkCubit x) => x.state.networkConnected);
    final errLoadingNetwork =
        context.select((NetworkCubit x) => x.state.errLoadingNetworks);
    final isTestnet = context.select((NetworkCubit x) => x.state.testnet);
    var network = context.select(
      (NetworkCubit x) => x.state.getNetwork()?.getNetworkUrl(isTestnet) ?? '',
    );
    var liqNetwork = context.select(
      (NetworkCubit x) =>
          x.state.getLiquidNetwork()?.getNetworkUrl(isTestnet) ?? '',
    );

    network = removeSubAndPort(network);
    liqNetwork = removeSubAndPort(liqNetwork);

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
            BBText.bodySmall(isLiq ? liqNetwork : network),
            if (networkConnected == false && errLoadingNetwork.isEmpty) ...[
              const Gap(24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(),
              ),
            ],
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
    final isLiq = context.select((_NetworkSelector _) => _.state);

    final tempSelected =
        context.select((NetworkCubit x) => x.state.tempNetwork);
    final tempLiqSelected =
        context.select((NetworkCubit x) => x.state.tempLiquidNetwork);
    final network = context.select((NetworkCubit x) => x.state.selectedNetwork);
    final liqNetwork =
        context.select((NetworkCubit x) => x.state.selectedLiquidNetwork);

    final selected = tempSelected ?? network;
    final liqSelected = tempLiqSelected ?? liqNetwork;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SegmentButton(
          index: 0,
          isSelected: isLiq
              ? liqSelected == LiquidElectrumTypes.blockstream
              : selected == ElectrumTypes.blockstream,
          text: 'Blockstream',
        ),
        // if (!isLiq)
        _SegmentButton(
          index: 1,
          isSelected: isLiq
              ? liqSelected == LiquidElectrumTypes.bullbitcoin
              : selected == ElectrumTypes.bullbitcoin,
          text: 'Bull Bitcoin',
        ),
        _SegmentButton(
          index: 2,
          isSelected: isLiq
              ? liqSelected == LiquidElectrumTypes.custom
              : selected == ElectrumTypes.custom,
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
    final isLiq = context.select((_NetworkSelector _) => _.state);

    final selectedBGColour = context.colour.surface.withOpacity(0.3);
    final unselectedBGColour = context.colour.surface.withOpacity(0.1);

    return Expanded(
      child: InkWell(
        onTap: () {
          if (!isLiq) {
            final network =
                context.read<NetworkCubit>().state.networkFromString(text);
            if (network == null) return;
            context.read<NetworkCubit>().networkTypeTempChanged(network);
            return;
          }

          final network =
              context.read<NetworkCubit>().state.liqNetworkFromString(text);
          if (network == null) return;
          context.read<NetworkCubit>().liqNetworkTypeTempChanged(network);
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
                color: isSelected
                    ? context.colour.primary
                    : context.colour.surface,
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

    final isLiq = context.select((_NetworkSelector _) => _.state);

    final network =
        context.select((NetworkCubit _) => _.state.getTempOrSelectedNetwork());
    if (network == null) return const SizedBox.shrink();

    final liqNetwork = context
        .select((NetworkCubit _) => _.state.getTempOrSelectedLiquidNetwork());
    if (liqNetwork == null) return const SizedBox.shrink();

    final tempNetworkDetails =
        context.select((NetworkCubit _) => _.state.tempNetworkDetails);
    if (tempNetworkDetails == null) return const SizedBox.shrink();

    final tempLiqNetworkDetails =
        context.select((NetworkCubit _) => _.state.tempLiquidNetworkDetails);
    if (tempLiqNetworkDetails == null) return const SizedBox.shrink();

    final type = network.type;
    final liqType = liqNetwork.type;

    final loading = context.select((NetworkCubit x) => x.state.loadingNetworks);

    final showButton = context
        .select((NetworkCubit x) => x.state.showConfirmButton(isLiquid: isLiq));

    var mainnet = isLiq ? liqNetwork.mainnet : network.mainnet;
    var testnet = isLiq ? liqNetwork.testnet : network.testnet;

    final disabled = isLiq
        ? liqType != LiquidElectrumTypes.custom
        : type != ElectrumTypes.custom;

    final mainnetChanged = isLiq
        ? mainnet != tempLiqNetworkDetails.mainnet
        : mainnet != tempNetworkDetails.mainnet;

    final testnetChanged = isLiq
        ? testnet != tempLiqNetworkDetails.testnet
        : testnet != tempNetworkDetails.testnet;

    if (mainnetChanged) {
      mainnet =
          isLiq ? tempLiqNetworkDetails.mainnet : tempNetworkDetails.mainnet;
    }

    if (testnetChanged) {
      testnet =
          isLiq ? tempLiqNetworkDetails.testnet : tempNetworkDetails.testnet;
    }

    if (disabled) {
      mainnet = removeSubAndPort(mainnet);
      testnet = removeSubAndPort(testnet);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(16),
          if (!disabled) ...[
            const BBText.title('    Mainnet'),
            const Gap(4),
            SizedBox(
              width: fieldWidth,
              child: BBTextInput.big(
                onChanged: (t) {
                  if (!isLiq) {
                    context.read<NetworkCubit>().updateTempMainnet(t);
                  } else {
                    context.read<NetworkCubit>().updateTempLiquidMainnet(t);
                  }
                },
                value: mainnet,
                disabled: disabled,
              ),
            ),
            const Gap(16),
            const BBText.title('    Testnet'),
            const Gap(4),
            SizedBox(
              width: fieldWidth,
              child: BBTextInput.big(
                onChanged: (t) {
                  if (!isLiq) {
                    context.read<NetworkCubit>().updateTempTestnet(t);
                  } else {
                    context.read<NetworkCubit>().updateTempLiquidTestnet(t);
                  }
                },
                value: testnet,
                disabled: disabled,
              ),
            ),
          ],
          if (!isLiq) ...[
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
          ],
          const Gap(40),
          // if (err.isNotEmpty) ...[
          //   BBText.error(err),
          //   const Gap(8),
          // ],
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
                // FocusScope.of(context).requestFocus(FocusNode());

                if (type == ElectrumTypes.custom) {
                  await PrivacyNoticePopUp.openPopUp(context);
                  return;
                }

                context
                    .read<NetworkCubit>()
                    .networkConfigsSaveClicked(isLiq: isLiq);
                // await Future.delayed(const Duration(milliseconds: 500));
                // final err =
                // context.read<NetworkCubit>().state.errLoadingNetworks;
                //if (err.isEmpty) context.pop();
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
      child: BlocProvider.value(
        value: context.read<_NetworkSelector>(),
        child: const PrivacyNoticePopUp(),
      ),
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
                    context.read<NetworkCubit>().networkConfigsSaveClicked(
                          isLiq: context.read<_NetworkSelector>().state,
                        );
                    context.pop();
                    /*
                    await Future.delayed(const Duration(milliseconds: 500));
                    final err =
                        context.read<NetworkCubit>().state.errLoadingNetworks;
                    if (err.isNotEmpty)
                      context.pop();
                    else
                      context
                        ..pop()
                        ..pop();
                        */
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

    final sg =
        context.select((NetworkCubit x) => x.state.tempNetworkDetails?.stopGap);
    final r =
        context.select((NetworkCubit x) => x.state.tempNetworkDetails?.retry);
    final t =
        context.select((NetworkCubit x) => x.state.tempNetworkDetails?.timeout);

    final showButton = context
        .select((NetworkCubit x) => x.state.showConfirmButton(isLiquid: false));

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
