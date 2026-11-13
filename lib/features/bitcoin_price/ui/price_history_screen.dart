import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/price_chart_widget.dart';
import 'package:bull_ui/bull_ui.dart';

class PriceHistoryScreen extends StatelessWidget {
  const PriceHistoryScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return BullScaffold(
      body: SafeArea(
        child: Column(
          children: [
            BullTopBar(title: context.loc.priceHistoryTitle, onBack: onBack),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: Container(
                    color: context.appColors.primaryFixed,
                    height: constraints.maxHeight < 320
                        ? 320
                        : constraints.maxHeight,
                    child: const PriceChartWidget(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
