import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/virtual_iban/domain/virtual_iban_location.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:bb_mobile/features/virtual_iban/ui/virtual_iban_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class VirtualIbanActiveScreen extends StatelessWidget {
  const VirtualIbanActiveScreen({
    super.key,
    this.onContinue,
    this.location = VirtualIbanLocation.funding,
  });

  final VoidCallback? onContinue;

  /// The context location - used for UI text and navigation behavior.
  /// Defaults to funding since that's the most common entry point.
  final VirtualIbanLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<VirtualIbanBloc, VirtualIbanState>(
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(context.loc.confidentialSepaTitle),
            scrolledUnderElevation: 0.0,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: context.appColors.surfaceContainer,
                      child: Icon(
                        Icons.check,
                        size: 48,
                        color: context.appColors.success,
                      ),
                    ),
                    const Gap(24.0),
                    BBText(
                      context.loc.confidentialSepaActivatedTitle,
                      style: theme.textTheme.displaySmall,
                      textAlign: TextAlign.center,
                    ),
                    const Gap(16.0),
                    BBText(
                      _getActivationDescription(context),
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBButton.big(
                    label: location == VirtualIbanLocation.funding
                        ? context.loc.showVirtualIbanDetails
                        : context.loc.continueButton,
                    onPressed: () {
                      if (onContinue != null) {
                        onContinue!();
                      } else if (location == VirtualIbanLocation.funding) {
                        context.pushNamed(VirtualIbanRoute.details.name);
                      } else {
                        Navigator.of(context).pop(true);
                      }
                    },
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                  if (location != VirtualIbanLocation.funding) ...[
                    const Gap(12),
                    BBButton.big(
                      label: context.loc.showVirtualIbanDetails,
                      onPressed: () {
                        context.pushNamed(VirtualIbanRoute.details.name);
                      },
                      outlined: true,
                      borderColor: context.appColors.outline,
                      bgColor: context.appColors.transparent,
                      textColor: context.appColors.onSurface,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getActivationDescription(BuildContext context) {
    switch (location) {
      case VirtualIbanLocation.funding:
        return context.loc.confidentialSepaActivatedFundingDesc;
      case VirtualIbanLocation.sell:
        return context.loc.confidentialSepaActivatedSellDesc;
      case VirtualIbanLocation.withdraw:
        return context.loc.confidentialSepaActivatedWithdrawDesc;
    }
  }
}
