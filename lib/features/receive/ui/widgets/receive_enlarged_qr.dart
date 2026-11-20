import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ReceiveEnlargedQr extends StatelessWidget {
  const ReceiveEnlargedQr({
    super.key,
    required this.data,
    required this.caption,
  });
  final String data;
  final String caption;

  static Future<void> show(BuildContext context) async {
    final bloc = context.read<ReceiveBloc>();
    await BullDialog.show<void>(
      context: context,
      fullscreen: true,
      padding: EdgeInsets.zero,
      barrierColor: context.appColors.scrim.withValues(alpha: 0.88),
      builder: (_) => BlocBuilder<ReceiveBloc, ReceiveState>(
        bloc: bloc,
        builder: (context, state) => ReceiveEnlargedQr(
          data: state.displayQrData,
          caption: state.isLightning
              ? '${context.loc.receiveLightningInvoice} · ${FormatAmount.sats(state.lightningAmountSat ?? state.confirmedAmountSat ?? 0)}'
              : '${state.wallet?.displayLabel(context) ?? ''} · ${StringFormatting.truncateMiddle(state.addressOrInvoiceOnly)}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Container(color: context.bull.transparent),
      ),
      SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: BullInlineIconButton(
                    tooltip: context.loc.closeDialogButton,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: BullIcon(
                      BullIcons.close,
                      color: context.appColors.surfaceFixed,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final size = constraints.maxWidth
                              .clamp(0, 358)
                              .toDouble();
                          return AbsorbPointer(
                            child: SizedBox.square(
                              dimension: size,
                              child: data.isEmpty
                                  ? const Center(child: BullLoader.small())
                                  : BullQrCode(
                                      data: data,
                                      size: size,
                                      semanticsLabel: caption,
                                    ),
                            ),
                          );
                        },
                      ),
                      const Gap(24),
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: context.bullType.body.copyWith(
                          color: context.appColors.surfaceFixed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Gap(92),
          ],
        ),
      ),
    ],
  );
}
