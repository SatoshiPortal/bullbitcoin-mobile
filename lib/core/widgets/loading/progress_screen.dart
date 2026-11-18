import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullLoader, BullText, Gap, BullTypographyX;

class ProgressScreen extends StatelessWidget {
  final String? title;
  final String? description;
  final bool isLoading;
  const ProgressScreen({
    required this.isLoading,
    super.key,
    this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          if (isLoading) const Center(child: BullLoader.large()),
          if (title != null) ...[
            const Gap(16),
            BullText(
              title!,
              textAlign: .center,
              style: context.bullType.subtitle
                  .copyWith(fontWeight: FontWeight.w700)
                  .copyWith(fontWeight: .bold),
            ),
          ],
          if (description != null) ...[
            const Gap(16),
            BullText(
              description!,
              textAlign: .center,
              style: context.bullType.label.copyWith(
                fontWeight: FontWeight.w400,
              ),
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }
}
