import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_coldcard/router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ColdcardDeviceSelectionBottomSheet {
  static Future<void> show(BuildContext context) {
    return BlurredBottomSheet.show(
      context: context,
      isDismissible: true,
      child: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.colour.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BBText(
                'Choose your Coldcard model',
                style: context.font.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const Gap(24),
              BBButton.small(
                label: 'Coldcard Q',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pushNamed(
                    ImportColdcardRoute.importColdcard.name,
                    extra: SignerDeviceEntity.coldcardQ,
                  );
                },
                bgColor: context.colour.onSecondary,
                textColor: context.colour.secondary,
                outlined: true,
              ),
              const Gap(16),
              BBButton.small(
                label: 'Coldcard Mk4',
                onPressed: () {
                  Navigator.of(context).pop();
                  context.pushNamed(
                    ImportColdcardRoute.importColdcard.name,
                    extra: SignerDeviceEntity.coldcardMk4,
                  );
                },
                bgColor: context.colour.onSecondary,
                textColor: context.colour.secondary,
                outlined: true,
              ),
              const Gap(16),
            ],
          ),
        ),
      ),
    );
  }
}
