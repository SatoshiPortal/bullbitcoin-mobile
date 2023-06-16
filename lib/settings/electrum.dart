import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class TestNetButton extends StatelessWidget {
  const TestNetButton({super.key});

  @override
  Widget build(BuildContext context) {
    final testnet = context.select((SettingsCubit x) => x.state.testnet);

    return Row(
      children: [
        // const Gap(8),
        const BBText.body(
          'Testnet mode',
        ),
        const Spacer(),
        Switch(
          key: UIKeys.settingsTestnetSwitch,
          value: testnet,
          onChanged: (e) {
            context.read<SettingsCubit>().toggleTestnet();
          },
        ),
      ],
    );
  }
}

class NetworkButton extends StatelessWidget {
  const NetworkButton({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedNetwork = context.select((SettingsCubit x) => x.state.getNetwork());
    if (selectedNetwork == null) return const SizedBox.shrink();
    final err = context.select((SettingsCubit x) => x.state.errLoadingNetworks);

    return Column(
      children: [
        InkWell(
          onTap: () {
            NetworkPopup.openPopUp(context);
          },
          child: Row(
            children: [
              BBButton.text(
                onPressed: () {
                  NetworkPopup.openPopUp(context);
                },
                label: 'Electrum server',
              ),
              const Gap(6),
              FaIcon(
                FontAwesomeIcons.angleRight,
                size: 14,
                color: context.colour.secondary,
              )
            ],
          ),
        ),
        if (err.isNotEmpty)
          BBText.body(
            err,
          ),
      ],
    );
  }
}

class NetworkPopup extends StatelessWidget {
  const NetworkPopup({super.key});

  static Future openPopUp(BuildContext context) {
    return showMaterialModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => const NetworkPopup(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const PopUpBorder(
      child: NetworkScreen(),
    );
  }
}

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final networks = context.select((SettingsCubit x) => x.state.networks);
    final selected = context.select((SettingsCubit x) => x.state.selectedNetwork);

    if (networks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const BBText.body(
                'Select network',
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  context.pop();
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Gap(32),
          CupertinoSlidingSegmentedControl(
            groupValue: selected,
            onValueChanged: (i) {
              context.read<SettingsCubit>().changeNetwork(i ?? 0);
            },
            children: const {
              0: BBText.body('Default'),
              1: BBText.body('Bull Bitcoin'),
              2: BBText.body('Custom'),
            },
          ),
          const Gap(8),
          const Divider(),
          const Gap(16),
          const NetworkConfigFields(),
          const Gap(80),
        ],
      ),
    );
  }
}

class NetworkConfigFields extends HookWidget {
  const NetworkConfigFields({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fieldWidth = MediaQuery.of(context).size.width * 0.7;

    final network = context.select((SettingsCubit x) => x.state.getNetwork());
    final index = context.select((SettingsCubit x) => x.state.selectedNetwork);
    final err = context.select((SettingsCubit x) => x.state.errLoadingNetworks);

    if (network == null) return const SizedBox.shrink();

    final mainnet = useTextEditingController(text: network.mainnet);
    final testnet = useTextEditingController(text: network.testnet);
    final stopGap = useTextEditingController(text: network.stopGap.toString());
    final retry = useTextEditingController(text: network.retry.toString());
    final timeout = useTextEditingController(text: network.timeout.toString());
    final validateDomain = useState(network.validateDomain);

    useEffect(
      () {
        mainnet.text = network.mainnet;
        testnet.text = network.testnet;
        stopGap.text = network.stopGap.toString();
        retry.text = network.retry.toString();
        timeout.text = network.timeout.toString();
        validateDomain.value = network.validateDomain;
        return null;
      },
      [network],
    );

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: fieldWidth,
            child: TextField(
              enabled: index == 2,
              controller: mainnet,
              style: index != 2 ? const TextStyle(color: Colors.grey) : null,
              decoration: const InputDecoration(labelText: 'Mainnet'),
            ),
          ),
          const Gap(16),
          SizedBox(
            width: fieldWidth,
            child: TextField(
              enabled: index == 2,
              controller: testnet,
              style: index != 2 ? const TextStyle(color: Colors.grey) : null,
              decoration: const InputDecoration(labelText: 'Testnet'),
            ),
          ),
          const Gap(16),
          SizedBox(
            width: fieldWidth,
            child: TextField(
              controller: stopGap,
              decoration: const InputDecoration(
                labelText: 'Stop gap',
              ),
            ),
          ),
          const Gap(16),
          SizedBox(
            width: fieldWidth,
            child: TextField(
              controller: retry,
              decoration: const InputDecoration(
                labelText: 'Retry',
              ),
            ),
          ),
          const Gap(16),
          SizedBox(
            width: fieldWidth,
            child: TextField(
              controller: timeout,
              decoration: const InputDecoration(
                labelText: 'Timeout',
              ),
            ),
          ),
          const Gap(16),
          Row(
            children: [
              const BBText.body('Validate domain'),
              IgnorePointer(
                ignoring: index != 2,
                child: Switch(
                  value: validateDomain.value,
                  onChanged: (e) {
                    validateDomain.value = e;
                  },
                ),
              ),
            ],
          ),
          const Gap(32),
          BBButton.bigRed(
            onPressed: () {
              FocusScope.of(context).requestFocus(FocusNode());
              final updatednetwork = network.copyWith(
                mainnet: mainnet.text,
                testnet: testnet.text,
                stopGap: int.tryParse(stopGap.text) ?? 20,
                retry: int.tryParse(retry.text) ?? 5,
                timeout: int.tryParse(timeout.text) ?? 5,
                validateDomain: validateDomain.value,
              );
              context.read<SettingsCubit>().networkConfigsSaveClicked(updatednetwork);
            },
            label: 'SAVE',
            filled: true,
          ),
          const Gap(8),
          if (err.isNotEmpty)
            BBText.body(
              err,
            ),
          const Gap(40),
        ],
      ),
    );
  }
}
