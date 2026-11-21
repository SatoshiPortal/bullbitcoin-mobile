import 'dart:async';

import 'package:signers/src/signer_device.dart';
import 'package:bull_ui/bull_ui.dart' show BullThemeX;
import 'package:signers/src/signers_l10n.dart';
import 'package:signers/src/psbt_flow/presentation/psbt_flow_failure_l10n.dart';
import 'package:signers/src/psbt_flow/show_animated_qr/show_animated_qr_cubit.dart';
import 'package:signers/src/psbt_flow/show_animated_qr/show_animated_qr_state.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullQrCode, BullShapesX, BullText, Gap, BullTypographyX;

class ShowAnimatedQrWidget extends StatelessWidget {
  final GetIt services;
  final String psbt;
  final QrType qrType;
  final bool showSlider;

  const ShowAnimatedQrWidget({
    super.key,
    required this.services,
    required this.psbt,
    required this.qrType,
    this.showSlider = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          services<ShowAnimatedQrCubit>(param1: psbt, param2: qrType),
      child: _ShowAnimatedQrView(showSlider: showSlider),
    );
  }
}

class _ShowAnimatedQrView extends StatefulWidget {
  final bool showSlider;

  const _ShowAnimatedQrView({required this.showSlider});

  @override
  State<_ShowAnimatedQrView> createState() => _ShowAnimatedQrViewState();
}

class _ShowAnimatedQrViewState extends State<_ShowAnimatedQrView> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debouncedCallback(int fragmentLength) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      context.read<ShowAnimatedQrCubit>().updateFragmentLength(fragmentLength);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ShowAnimatedQrCubit, ShowAnimatedQrState>(
      builder: (context, state) {
        if (state.isLoading) {
          return Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: context.bull.surfaceFixed,
              borderRadius: BorderRadius.circular(context.bullShapes.card),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state.failure case final failure?) {
          return Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: context.bull.surfaceFixed,
              borderRadius: BorderRadius.circular(context.bullShapes.card),
            ),
            child: Center(
              child: Text(
                failure.toTranslated(context),
                textAlign: TextAlign.center,
                style: context.bullType.body.copyWith(
                  color: context.bull.error,
                ),
              ),
            ),
          );
        }

        if (state.parts.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            color: context.bull.background,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
          ),
          child: Column(
            mainAxisAlignment: .start,
            children: [
              // QR must keep a generous white quiet zone in dark mode so
              // hardware scanners (Jade, ColdCard) can detect the code on
              // large PSBT payloads. See #1917.
              BullQrCode(
                data: state.parts[state.currentIndex],
                size: 300,
                semanticsLabel: context.loc.receiveQRCode,
              ),
              const Gap(16),
              if (widget.showSlider) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Builder(
                    builder: (context) {
                      final currentValue = state.fragmentLength
                          .toDouble()
                          .clamp(25.0, 200.0);

                      return MergeSemantics(
                        child: Semantics(
                          label: context.loc.psbtFlowQrDensity,
                          child: Slider(
                            value: currentValue,
                            min: 25.0,
                            max: 200.0,
                            activeColor: context.bull.secondary,
                            inactiveColor: context.bull.surfaceContainer,
                            onChanged: (value) {
                              final newFragmentLength = value.round();
                              context
                                  .read<ShowAnimatedQrCubit>()
                                  .updateFragmentLength(newFragmentLength);
                              _debouncedCallback(newFragmentLength);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Gap(16),
              ],

              if (state.parts.length > 1) ...[
                BullText(
                  context.loc.psbtFlowPartProgress(
                    (state.currentIndex + 1).toString(),
                    state.parts.length.toString(),
                  ),
                  style: context.bullType.body.copyWith(
                    color: context.bull.secondary,
                  ),
                ),
                const Gap(8),
              ],
            ],
          ),
        );
      },
    );
  }
}
