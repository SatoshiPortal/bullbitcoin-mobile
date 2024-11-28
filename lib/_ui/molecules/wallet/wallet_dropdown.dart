import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/molecules/wallet/wallet_card.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDropDown extends StatelessWidget {
  const WalletDropDown({
    super.key,
    required this.items,
    required this.onChanged,
    required this.value,
    this.isCentered = true,
    this.disabled = false,
    this.showSpendableBalance = false,
  });

  final List<Wallet> items;
  final void Function(Wallet) onChanged;
  final Wallet value;
  final bool isCentered;
  final bool disabled;
  final bool showSpendableBalance;

  @override
  Widget build(BuildContext context) {
    context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final balance = context.select(
      (CurrencyCubit x) =>
          x.state.getAmountInUnits(value.balance ?? 0, removeText: true),
    );
    final unit = context.select(
      (CurrencyCubit x) => x.state.getUnitString(isLiquid: value.isLiquid()),
    );

    final widget = DropdownButtonHideUnderline(
      child: DropdownButton<Wallet>(
        padding: EdgeInsets.zero,
        itemHeight: null,
        iconSize: 0.0,
        value: value,
        dropdownColor: context.colour.primaryContainer,
        onChanged: disabled
            ? null
            : (value) {
                if (value == null) return;
                onChanged.call(value);
              },
        selectedItemBuilder: (context) => items.map((key) {
          final widget = buildCard(key, balance, unit, showSpendableBalance);
          return widget;
        }).toList(),
        items: [
          for (final w in items)
            DropdownMenuItem(
              value: w,
              child: buildMenuItem(w),
            ),
        ],
      ),
    );

    return widget;
  }
}

Widget buildCard(
  Wallet w,
  String balance,
  String unit,
  bool showSpendableBalance,
) {
  final walletCard = WalletCard(
    wallet: w,
    balance: balance,
    balanceUnit: unit,
  );
  if (showSpendableBalance == false) {
    return walletCard;
  }

  final frozenUtxos = w.allFreezedUtxos();
  if (frozenUtxos.isEmpty) {
    return walletCard;
  } else {
    final balance = w.balanceWithoutFrozenUTXOs();
    return Column(
      children: [walletCard, Text('Spendable: $balance sats')],
    );
  }
}

Widget buildMenuItem(Wallet w) {
  final text = w.name ?? '';

  final textWidget = BBText.body(text);

  return Center(
    child: textWidget,
  );
}
