import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/inline_label.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/_ui/templates/headers.dart';
import 'package:bb_mobile/address/pop_up.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/wallet/bloc/wallet_cubit.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class AddressesScreen extends HookWidget {
  const AddressesScreen({super.key});

  static Future openPopup(
    BuildContext context,
  ) {
    final wallet = context.read<WalletCubit>();
    final walletSettings = context.read<WalletSettingsCubit>();

    return showMaterialModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: wallet),
          BlocProvider.value(value: walletSettings),
        ],
        child: const PopUpBorder(
          child: AddressesScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = useState(0);

    final addresses = context.select((WalletCubit cubit) => cubit.state.wallet!.allAddresses());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: BBHeader.popUpCenteredText(
              text: 'Addresses',
              isLeft: true,
            ),
          ),
          // Row(
          //   children: [
          //     const Gap(40),
          //     const Spacer(),
          //     const BBHeader.popUpCenteredText(
          //       text: 'Addresses',

          //     ),
          //     const Spacer(),
          //     IconButton(
          //       icon: const Icon(FontAwesomeIcons.xmark),
          //       onPressed: () => context.pop(),
          //     ),
          //     const Gap(16),
          //   ],
          // ),
          const Gap(24),
          SelectAddressType(
            onSelected: (i) {
              selectedOption.value = i;
            },
            selectedOption: selectedOption.value,
          ),
          const Gap(32),
          if (selectedOption.value == 0) ...[
            if (addresses
                .where((element) => element.getAddressListType() == AddressListType.receiveActive)
                .isNotEmpty) ...[
              const BBText.title(
                'Active Balance',
              ),
              const Gap(8),
              for (var i = 0; i < addresses.length; i++)
                if (addresses[i].getAddressListType() == AddressListType.receiveActive)
                  AddressItem(address: addresses[i]),
              const Gap(16),
            ],
            if (addresses
                .where((element) => element.getAddressListType() == AddressListType.receiveUnused)
                .isNotEmpty) ...[
              const BBText.title(
                'Unused',
              ),
              const Gap(8),
              for (var i = 0; i < addresses.length; i++)
                if (addresses[i].getAddressListType() == AddressListType.receiveUnused)
                  AddressItem(address: addresses[i]),
              const Gap(16),
            ],
            if (addresses
                .where((element) => element.getAddressListType() == AddressListType.receiveUsed)
                .isNotEmpty) ...[
              const BBText.title(
                'Previously used',
              ),
              const Gap(8),
              for (var i = 0; i < addresses.length; i++)
                if (addresses[i].getAddressListType() == AddressListType.receiveUsed)
                  AddressItem(address: addresses[i]),
              const Gap(16),
            ],
          ] else ...[
            if (addresses
                .where((element) => element.getAddressListType() == AddressListType.changeActive)
                .isNotEmpty) ...[
              const BBText.title(
                'Active Balance',
              ),
              const Gap(8),
              for (var i = 0; i < addresses.length; i++)
                if (addresses[i].getAddressListType() == AddressListType.changeActive)
                  AddressItem(address: addresses[i]),
              const Gap(16),
            ],
            if (addresses
                .where((element) => element.getAddressListType() == AddressListType.changeUsed)
                .isNotEmpty) ...[
              const BBText.title(
                'Previously used',
              ),
              const Gap(8),
              for (var i = 0; i < addresses.length; i++)
                if (addresses[i].getAddressListType() == AddressListType.changeUsed)
                  AddressItem(address: addresses[i]),
              const Gap(16),
            ],
          ],
          const Gap(100),
        ],
      ),
    );
  }
}

class SelectAddressType extends StatelessWidget {
  const SelectAddressType({
    super.key,
    required this.onSelected,
    required this.selectedOption,
  });

  final Function(int) onSelected;
  final int selectedOption;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        InkWell(
          onTap: () {
            onSelected(0);
          },
          child: BBText.body(
            'RECEIVE',
            isBold: selectedOption == 0,
            isBlue: selectedOption != 0,
          ),
        ),
        InkWell(
          onTap: () {
            onSelected(1);
          },
          child: BBText.body(
            'CHANGE',
            isBold: selectedOption == 1,
            isBlue: selectedOption != 1,
          ),
        ),
      ],
    );
  }
}

class AddressItem extends StatelessWidget {
  const AddressItem({
    super.key,
    required this.address,
  });

  final Address address;

  @override
  Widget build(BuildContext context) {
    final balance = address.calculateBalance();
    final amt = context.select(
      (SettingsCubit x) => x.state.getAmountInUnits(balance),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () async {
              AddressPopUp.openPopup(context, address);
            },
            child: BBText.body(
              address.address,
              isBlue: true,
            ),
          ),
          const Gap(4),
          if (amt.isNotEmpty) InlineLabel(title: 'Balance', body: amt),
          if (address.label != null && address.label!.isNotEmpty) ...[
            const Gap(4),
            InlineLabel(title: 'Label', body: address.label!),
            const Gap(8),
          ],
        ],
      ),
    );
  }
}
