import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gif/gif.dart';

class KeyServerStatusWidget extends StatelessWidget {
  const KeyServerStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<RecoverBullBloc>().state.keyServerStatus;

    return GestureDetector(
      onTap: () {
        context.read<RecoverBullBloc>().add(const OnServerCheck());
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (status == KeyServerStatus.connecting)
            Gif(
              image: AssetImage(Assets.animations.cubesLoading.path),
              autostart: Autostart.loop,
              height: 55,
              width: 55,
            )
          else
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Key Server ',
                    style: context.font.labelLarge?.copyWith(
                      fontSize: 12,
                      color: context.colour.secondary,
                    ),
                  ),

                  WidgetSpan(
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: switch (status) {
                        KeyServerStatus.online => context.colour.inverseSurface,
                        KeyServerStatus.offline => context.colour.error,
                        KeyServerStatus.connecting => context.colour.secondary,
                        KeyServerStatus.unknown => context.colour.secondary,
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
