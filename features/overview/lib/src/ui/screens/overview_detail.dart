import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';

class OverviewDetail extends StatelessWidget {
  final String walletName;
  final Widget settings;
  final bool isLoading;
  final String unavailableMessage;
  final Widget? body;
  final Widget bottomActions;

  const OverviewDetail({
    super.key,
    required this.walletName,
    required this.settings,
    required this.isLoading,
    required this.unavailableMessage,
    required this.body,
    required this.bottomActions,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: walletName.isEmpty
          ? const BullShimmerLine(width: 150)
          : BullText(
              walletName,
              style: context.bullType.subtitle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
      actions: [settings],
    ),
    body: isLoading
        ? const BullShimmerBox(height: 100)
        : body ??
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(unavailableMessage, textAlign: TextAlign.center),
                ),
              ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 16),
        child: bottomActions,
      ),
    ),
  );
}
