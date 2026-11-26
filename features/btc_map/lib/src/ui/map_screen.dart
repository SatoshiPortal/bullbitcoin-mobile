import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:btc_map/src/presentation/map_localizations_x.dart';
import 'package:btc_map/src/presentation/map_cubit.dart';
import 'package:btc_map/src/presentation/map_failure_l10n.dart';
import 'package:btc_map/src/presentation/map_state.dart';
import 'package:btc_map/src/ui/widgets/merchant_details_sheet.dart';
import 'package:btc_map/src/ui/widgets/merchant_list_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = BullMapController();
  bool _isPreparingPins = false;

  @override
  Widget build(BuildContext context) {
    return BullScaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.btcMapLoc.merchantMapTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: BlocConsumer<MapCubit, MapState>(
        listenWhen: (previous, current) =>
            current.failure != null &&
            previous.failure != current.failure &&
            current.merchants.isNotEmpty,
        listener: (context, state) => BullSnackBar.show(
          context,
          message: context.btcMapLoc.merchantMapShowingSavedData,
          actionLabel: context.btcMapLoc.retry,
          onAction: () => context.read<MapCubit>().refresh(),
        ),
        builder: (context, state) => Stack(
          children: [
            BullMapView(
              merchants: state.mapMerchants,
              controller: _mapController,
              initialCenter: state.initialCenter,
              onMerchantTap: _showMerchant,
              onPreparingChanged: (preparing) {
                if (mounted && _isPreparingPins != preparing) {
                  setState(() => _isPreparingPins = preparing);
                }
              },
              onViewportChanged: context.read<MapCubit>().viewportChanged,
            ),
            Align(
              alignment: Alignment.topCenter,
              child: BullFadingLinearProgress(
                trigger: state.isSyncing || _isPreparingPins,
                backgroundColor: context.bull.surface,
                foregroundColor: context.bull.primary,
              ),
            ),
            if (state.failure case final failure? when state.isBlockingFailure)
              _BlockingFailure(message: failure.toTranslated(context))
            else
              MerchantListSheet(
                // Keyed so the failure card coming and going does not
                // rebuild the sheet and lose its position.
                key: const ValueKey('merchant-list-sheet'),
                onMerchantSelected: _openFromList,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFromList(Merchant merchant) async {
    await _mapController.focus(merchant.location);
    await _showMerchant(merchant);
  }

  Future<void> _showMerchant(Merchant merchant) async {
    if (!mounted) return;
    await showMerchantDetailsSheet(context, merchant);
  }
}

class _BlockingFailure extends StatelessWidget {
  const _BlockingFailure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullInfoCard(
            description: message,
            tagColor: context.bull.error,
            bgColor: context.bull.errorContainer,
          ),
          const Gap(16),
          BullButton.primary(
            size: BullButtonSize.small,
            key: const ValueKey('merchant-map-retry'),
            label: context.btcMapLoc.retry,
            onPressed: () => context.read<MapCubit>().refresh(),
          ),
        ],
      ),
    ),
  );
}
