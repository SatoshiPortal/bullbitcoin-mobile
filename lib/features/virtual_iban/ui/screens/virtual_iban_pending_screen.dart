import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/virtual_iban/domain/virtual_iban_location.dart';
import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class VirtualIbanPendingScreen extends StatelessWidget {
  const VirtualIbanPendingScreen({super.key, this.onUseRegularSepa});

  final VoidCallback? onUseRegularSepa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = context.select((VirtualIbanBloc bloc) {
      return bloc.state.location ?? VirtualIbanLocation.funding;
    });

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
                    Icons.schedule,
                    size: 48,
                    color: context.appColors.onSurface,
                  ),
                ),
                const Gap(24.0),
                BBText(
                  context.loc.activatingConfidentialSepaTitle,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const Gap(16.0),
                BBText(
                  _getDescriptionText(context, location),
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const Gap(32.0),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: context.appColors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.appColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BBButton.big(
            label: _getButtonText(context, location),
            onPressed: () {
              if (onUseRegularSepa != null) {
                onUseRegularSepa!();
              } else {
                Navigator.of(context).pop();
              }
            },
            outlined: true,
            borderColor: context.appColors.outline,
            bgColor: context.appColors.transparent,
            textColor: context.appColors.onSurface,
          ),
        ),
      ),
    );
  }

  String _getDescriptionText(
    BuildContext context,
    VirtualIbanLocation location,
  ) {
    return context.loc.activatingConfidentialSepaDesc;
  }

  String _getButtonText(BuildContext context, VirtualIbanLocation location) {
    switch (location) {
      case VirtualIbanLocation.funding:
        return context.loc.useRegularSepaInstead;
      case VirtualIbanLocation.sell:
      case VirtualIbanLocation.withdraw:
        return context.loc.useRegularSepaInstead;
    }
  }
}
