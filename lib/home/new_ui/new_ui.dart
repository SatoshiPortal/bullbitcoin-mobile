import 'package:auto_size_text/auto_size_text.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/new_ui/assets.gen.dart';
import 'package:bb_mobile/network/bloc/network_bloc.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.tagColor,
    required this.title,
    required this.description,
    required this.wallet,
    required this.onTap,
  });

  final Color tagColor;
  final String title;
  final String description;
  final Wallet wallet;

  final Function onTap;

  @override
  Widget build(BuildContext context) {
    final balance =
        context.select((CurrencyCubit x) => x.state.getAmountInUnits(
              wallet.balanceSats(),
              removeText: true,
            ));
    final unit = context.select(
      (CurrencyCubit x) => x.state.getUnitString(isLiquid: wallet.isLiquid()),
    );

    final fiatCurrency =
        context.select((CurrencyCubit x) => x.state.defaultFiatCurrency);

    final fiatAmt = context.select(
      (NetworkBloc x) => x.state.calculatePrice(
        wallet.balanceSats(),
        fiatCurrency,
      ),
    );

    final color = WalletCardDetails.cardDetails(context, wallet);

    return InkWell(
      onTap: () => onTap(),
      child: SizedBox(
        height: 80,
        child: Material(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(2),
          child: Row(
            children: [
              Container(
                width: 4,
                height: double.infinity,
                color: color.$1,
              ),
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(16),
                  BBBText(
                    title,
                    style: context.font.bodyLarge,
                    color: context.colour.secondary,
                  ),
                  const Gap(4),
                  BBBText(
                    description,
                    style: context.font.labelMedium,
                    color: context.colour.outline,
                  ),
                  const Gap(16),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Gap(16),
                  BBBText(
                    '$balance $unit',
                    style: context.font.bodyLarge,
                    color: context.colour.secondary,
                  ),
                  const Gap(4),
                  BBBText(
                    '$fiatAmt ${fiatCurrency?.name}',
                    style: context.font.labelMedium,
                    color: context.colour.outline,
                  ),
                  const Gap(16),
                ],
              ),
              const Gap(8),
              Icon(
                Icons.chevron_right,
                color: context.colour.outline,
                size: 24,
              ),
              const Gap(4),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ButtonPosition { first, last, middle }

class ActionCard extends StatelessWidget {
  const ActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(2),
            Container(
              // padding: const EdgeInsets.all(20),
              height: 70,
              color: context.colour.secondaryFixed,
              // color: Colors.red,
            ),
            // const Gap(2),
          ],
        ),
        const _ActionRow(),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      color: Colors.transparent,
      child: SizedBox(
        height: 80,
        child: Row(
          children: [
            _ActionButton(
              icon: Assets.icons.btc.path,
              label: 'Buy',
              onPressed: () {},
              position: _ButtonPosition.first,
            ),
            const Gap(1),
            _ActionButton(
              icon: Assets.icons.dollar.path,
              label: 'Sell',
              onPressed: () {},
              position: _ButtonPosition.middle,
            ),
            const Gap(1),
            _ActionButton(
              icon: Assets.icons.rightArrow.path,
              label: 'Pay',
              onPressed: () {
                context.push('/send');
              },
              position: _ButtonPosition.middle,
            ),
            const Gap(1),
            _ActionButton(
              icon: Assets.icons.swap.path,
              label: 'Swap',
              onPressed: () {
                context.push('/swap-page');
              },
              position: _ButtonPosition.last,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.position,
  });

  final String icon;
  final String label;
  final Function onPressed;
  final _ButtonPosition position;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(2);
    final radius = BorderRadius.only(
      topLeft: position == _ButtonPosition.first ? r : Radius.zero,
      topRight: position == _ButtonPosition.last ? r : Radius.zero,
      bottomLeft: position == _ButtonPosition.first ? r : Radius.zero,
      bottomRight: position == _ButtonPosition.last ? r : Radius.zero,
    );

    return Expanded(
      child: InkWell(
        onTap: () => onPressed(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: context.colour.onPrimary,
          ),
          child: Column(
            spacing: 8,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(icon, height: 24, width: 24),
              BBBText(
                label,
                style: context.font.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PriceCard extends StatelessWidget {
  const PriceCard({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return BBBText(
      text,
      style: context.font.displaySmall,
      color: context.colour.onPrimary,
    );
  }
}

class BBBText extends StatelessWidget {
  const BBBText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.color,
  });

  final String text;
  final int maxLines;
  final TextStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AutoSizeText(
      text,
      style: style!.copyWith(color: color),
      maxLines: maxLines,
    );
  }
}

enum _ButtonSize { small, large }

class BBBButton extends StatelessWidget {
  const BBBButton.big({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    required this.bgColor,
    required this.textColor,
    this.iconData,
    this.iconFirst = false,
    this.outlined = false,
  }) : size = _ButtonSize.large;

  const BBBButton.small({
    super.key,
    this.icon,
    required this.label,
    required this.onPressed,
    required this.bgColor,
    required this.textColor,
    this.iconData,
    this.iconFirst = false,
    this.outlined = false,
  }) : size = _ButtonSize.small;

  final String? icon;
  final IconData? iconData;

  final String label;
  final Color bgColor;
  final Color textColor;
  final bool iconFirst;
  final Function onPressed;
  final bool outlined;
  final _ButtonSize size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size == _ButtonSize.large ? 2 : 2);

    final image = iconData != null
        ? Icon(iconData, size: 20, color: textColor)
        : Image.asset(icon!, width: 20, height: 20, color: textColor);

    return InkWell(
      onTap: () => onPressed(),
      borderRadius: radius,
      child: Container(
        height: 52,
        width: size == _ButtonSize.large ? null : 160,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: !outlined ? bgColor : Colors.transparent,
          border: outlined ? Border.all(color: bgColor) : null,
          borderRadius: radius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconFirst) ...[
              image,
              const Gap(10),
              BBBText(
                label,
                style: context.font.headlineLarge,
                color: textColor,
              ),
            ] else ...[
              BBBText(
                label,
                style: context.font.headlineLarge,
                color: textColor,
              ),
              const Gap(10),
              image,
            ],
          ],
        ),
      ),
    );
  }
}

class AppFonts {
  static const _textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w500,
    ),
    displayMedium: TextStyle(
      fontSize: 43,
      fontWeight: FontWeight.w500,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      // height: 34,
    ),
    headlineLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      // height: 24,
    ),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      // height: 24,
    ),
    headlineSmall: TextStyle(
      fontSize: 16,
      // height: 24,
    ),
    // titleLarge: TextStyle(),
    // titleMedium: TextStyle(),
    // titleSmall: TextStyle(),
    bodyLarge: TextStyle(
      fontSize: 14,
      // height: 18,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      // height: 18,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      // height: 18,
    ),
    labelLarge: TextStyle(
      fontSize: 12,
      // height: 18,
      fontWeight: FontWeight.w500,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      // height: 18,
    ),
    labelSmall: TextStyle(
      fontSize: 10,
    ),
  );

  static ({String fontFamily, TextTheme textTheme}) textTheme = (
    fontFamily: 'Golos',
    textTheme: GoogleFonts.golosTextTextTheme(
      _textTheme,
    ),
  );
}

class AppColours {
  static ColorScheme lightColourScheme = ColorScheme(
    primary: const Color(0xFFC50909),
    secondary: const Color(0xFF15171C),
    onPrimary: const Color(0xFFFFFFFF),
    error: const Color(0xFFFF3B30),
    onError: const Color(0xFFFB9300),
    inverseSurface: const Color(0xFF34C759),
    inversePrimary: const Color(0xFF0063F7),
    surface: const Color(0xFFC9CACD),
    surfaceContainer: const Color(0xFF9C9FA5),
    outline: const Color(0xFF70747D),
    outlineVariant: const Color(0xFF444955),
    onSurfaceVariant: const Color(0xFF3E434E),
    surfaceContainerLow: const Color(0xFF22252B),
    onSurface: const Color(0xFF111215),
    tertiary: const Color(0xFFFFCC00),
    onTertiary: const Color(0xFFFF9500),
    surfaceDim: const Color(0xFFFFFFFF).withAlpha(_getAlpha(0.25)),
    surfaceBright: const Color(0xFFFFFFFF).withAlpha(_getAlpha(0.5)),
    scrim: const Color(0xFF000000).withAlpha(_getAlpha(0.15)),
    shadow: const Color(0xFF000000).withAlpha(_getAlpha(0.25)),
    tertiaryFixed: const Color(0xFF000000).withAlpha(_getAlpha(0.5)),
    tertiaryFixedDim: const Color(0xFF000000).withAlpha(_getAlpha(0.75)),
    secondaryFixed: const Color(0xFFF5F5F5),
    secondaryFixedDim: const Color(0xFFE6E6E6),
    onSecondaryFixed: const Color(0xFFD9D9D9),
    brightness: Brightness.light,
    onSecondary: const Color(0xFFFFFFFF),
  );

  static ColorScheme darkColourScheme = const ColorScheme(
    primary: Color(0xFFC50909),
    secondary: Color(0xFF15171C),
    onPrimary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFFFFFFFF),
    error: Color(0xFFFF3B30),
    onError: Color(0xFFFB9300),
    surface: Color(0xFFC9CACD),
    onSurface: Color(0xFF111215),
    brightness: Brightness.dark,
  );
}

int _getAlpha(double opacity) => (255 * opacity).toInt();
