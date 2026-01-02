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

/// Screen shown when Virtual IBAN has been successfully activated.
/// Shows success message and navigation options.
class VirtualIbanActiveScreen extends StatelessWidget {
  const VirtualIbanActiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = context.watch<VirtualIbanBloc>().state;
    final location = state.location;

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
                // Success icon
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

                // Title
                BBText(
                  context.loc.confidentialSepaActivatedTitle,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const Gap(16.0),

                // Context-aware description
                BBText(
                  _getActivationDescription(context, location),
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
                label:
                    location == VirtualIbanLocation.funding
                        ? context.loc.showVirtualIbanDetails
                        : context.loc.continueButton,
                onPressed: () {
                  if (location == VirtualIbanLocation.funding) {
                    // Navigate to details screen
                    context.pushNamed(VirtualIbanRoute.details.name);
                  } else {
                    // Return to the previous flow (sell/withdraw)
                    context.pop();
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
  }

  String _getActivationDescription(
    BuildContext context,
    VirtualIbanLocation? location,
  ) {
    switch (location) {
      case VirtualIbanLocation.funding:
        return context.loc.confidentialSepaActivatedFundingDesc;
      case VirtualIbanLocation.sell:
        return context.loc.confidentialSepaActivatedSellDesc;
      case VirtualIbanLocation.withdraw:
        return context.loc.confidentialSepaActivatedWithdrawDesc;
      case null:
        return context.loc.confidentialSepaActivatedFundingDesc;
    }
  }
}

