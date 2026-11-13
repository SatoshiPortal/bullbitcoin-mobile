part of '../public/settings_facade.dart';

class _AmountPreferencesBinder extends StatelessWidget {
  const _AmountPreferencesBinder({
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsCubit>().state;
    final settings = state.storedSettings;
    final isReady = settings != null && state.failure == null;
    return BullAmountScope(
      snapshot: BullAmountSnapshot(
        unit: settings?.bitcoinUnit ?? BitcoinUnit.btc,
        hideAmounts: !isReady || (settings.hideAmounts ?? true),
        isReady: isReady,
      ),
      writeUnit: (unit) async {
        final result = await context.read<SettingsCubit>().setBitcoinUnit(unit);
        return result is Ok<void, SettingsFailure>;
      },
      overlayResolver: () => navigatorKey.currentState?.overlay,
      child: child,
    );
  }
}
