import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class LightingPopUp extends StatelessWidget {
  const LightingPopUp({super.key});

  static Future openPopUp(BuildContext context) async {
    return showBBBottomSheet(
      context: context,
      child: const LightingPopUp(),
    );
  }

  void onClicked(BuildContext context, ThemeLighting theme) {
    context.pop();
    context.read<Lighting>().toggle(theme);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.select((Lighting e) => e.state);

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 56, left: 24, right: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BBHeader.popUpCenteredText(
            text: 'Lighting',
            isLeft: true,
            onBack: () => context.pop(),
          ),
          const Gap(8),
          ListTile(
            title: const BBText.body('Light'),
            onTap: () async {
              onClicked(context, ThemeLighting.light);
            },
            leading: Radio<ThemeLighting>(
              fillColor: MaterialStateProperty.all(context.colour.primary),
              value: ThemeLighting.light,
              groupValue: theme,
              onChanged: (value) {
                onClicked(context, value!);
              },
            ),
          ),
          ListTile(
            title: const BBText.body('Dark'),
            onTap: () {
              onClicked(context, ThemeLighting.dark);
            },
            leading: Radio<ThemeLighting>(
              value: ThemeLighting.dark,
              groupValue: theme,
              fillColor: MaterialStateProperty.all(context.colour.primary),
              onChanged: (value) {
                onClicked(context, value!);
              },
            ),
          ),
          ListTile(
            title: const BBText.body('Dimmed'),
            onTap: () {
              onClicked(context, ThemeLighting.dim);
            },
            leading: Radio<ThemeLighting>(
              value: ThemeLighting.dim,
              groupValue: theme,
              fillColor: MaterialStateProperty.all(context.colour.primary),
              onChanged: (value) {
                onClicked(context, value!);
              },
            ),
          ),
          ListTile(
            title: const BBText.body('System'),
            onTap: () {
              onClicked(context, ThemeLighting.system);
            },
            leading: Radio<ThemeLighting>(
              fillColor: MaterialStateProperty.all(context.colour.primary),
              value: ThemeLighting.system,
              groupValue: theme,
              onChanged: (value) {
                onClicked(context, value!);
              },
            ),
          ),
        ],
      ),
    );
  }
}
