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
  });

  final List<Wallet> items;
  final void Function(Wallet) onChanged;
  final Wallet value;
  final bool isCentered;

  @override
  Widget build(BuildContext context) {
    final darkMode = context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    final bgColour =
        darkMode ? context.colour.onPrimaryContainer : NewColours.offWhite;

    final balance = context.select(
      (CurrencyCubit x) =>
          x.state.getAmountInUnits(value.balance!, removeText: true),
    );
    final unit = context.select(
      (CurrencyCubit x) => x.state.getUnitString(isLiquid: value.isLiquid()),
    );

    final widget = DropdownButtonHideUnderline(
      child: DropdownButton<Wallet>(
        itemHeight: null,
        iconSize: 0.0,
        value: value,
        onChanged: (value) {
          if (value == null) return;
          print('onChanged');
          onChanged.call(value);
        },
        selectedItemBuilder: (context) => items.map((key) {
          final widget = buildCard(key, balance, unit);
          print(widget);
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

Widget buildCard(Wallet w, String balance, String unit) {
  print('buildCard');
  print(w.name);
  return WalletCard(
    wallet: w,
    balance: balance,
    balanceUnit: unit,
  );
}

Widget buildMenuItem(Wallet w) {
  /*
    final text = shorten
        ? item.label.length > 12
            ? item.label.substring(0, 12) + '...'
            : item.label
        : item.label;
        */
  final text = w.name!;

  final textWidget = BBText.body(text);

  return Center(
    child: textWidget,
  );
}
