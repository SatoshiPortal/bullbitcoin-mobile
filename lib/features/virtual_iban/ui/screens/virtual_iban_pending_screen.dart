import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

/// Screen shown when Virtual IBAN has been created but not yet activated.
/// Polls for activation status in the background.
class VirtualIbanPendingScreen extends StatelessWidget {
  const VirtualIbanPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                // Clock icon
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

                // Title
                BBText(
                  context.loc.activatingConfidentialSepaTitle,
                  style: theme.textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const Gap(16.0),

                // Description
                BBText(
                  context.loc.activatingConfidentialSepaDesc,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const Gap(32.0),

                // Loading indicator
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
            label: context.loc.useRegularSepaInstead,
            onPressed: () {
              // Navigate back to fund exchange or wherever makes sense
              context.pop();
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
}

