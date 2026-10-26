import '../../presentation/bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import '../../l10n/context_localizations.dart';
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
        mainAxisAlignment: .center,
        children: [
          if (status == KeyServerStatus.connecting)
            Gif(
              image: BullAssets.animations.cubesLoading,
              autostart: Autostart.loop,
              height: 55,
              width: 55,
            )
          else
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: context.loc.recoverbullKeyServer,
                    style: context.bullText.labelLarge?.copyWith(
                      fontSize: 12,
                      color: context.bull.onSurface,
                    ),
                  ),

                  WidgetSpan(
                    child: Icon(
                      Icons.circle,
                      size: 12,
                      color: switch (status) {
                        KeyServerStatus.online => context.bull.success,
                        KeyServerStatus.offline => context.bull.error,
                        KeyServerStatus.connecting => context.bull.textMuted,
                        KeyServerStatus.unknown => context.bull.textMuted,
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
