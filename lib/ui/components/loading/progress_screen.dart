import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProgressScreen extends StatelessWidget {
  final String? title;
  final String? description;
  final bool isLoading;
  final List<Widget> extras;
  const ProgressScreen({
    required this.isLoading,
    super.key,
    this.title,
    this.description,
    this.extras = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            Center(
              child: Image.network(
                "https://s3-alpha-sig.figma.com/img/8bc4/c05f/a9d95a1e4eb48bca4e89c563d5a731a1?Expires=1744588800&Key-Pair-Id=APKAQ4GOSFWCW27IBOMQ&Signature=mzHul7JycaOyzgh1Xx3FGcoUj9Hbg4vjRQIYTfvyzFwLzPZkX4aAKXvrUiTkeYX-fV8kPJDWkBi3z3YDuzK-Q80widmpuIPGgVYuKDGVD~6p-sN8D7yy-QNEjCh3G3BDvSSaWigX2KBJTQqbjKkBNORlkdgUA~iw7TL8GLz0s~0VyYO5aEnBBWlfBwRZjfeZZhKSe8tOAzQr5FEIHewYBI91tFQfaxSe6ps155kIXbDTDH-IwwhSQDx1y0iuFTo6BuzXMnCIeMayrHpWhKkqjTKa~6PiRD9KTDbseQPMpbWTBZnHlseL3yXDjN~8YGx32hLz7athKI5Zpq6d10fKaw__",
                width: 200,
                height: 200,
                fit: BoxFit.cover,
              ),
            )
          else
            const SizedBox.shrink(),
          if (title != null) ...[
            const Gap(16),
            BBText(
              title!,
              textAlign: TextAlign.center,
              style: context.font.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (description != null) ...[
            const Gap(16),
            BBText(
              description!,
              textAlign: TextAlign.center,
              style: context.font.bodySmall,
              maxLines: 3,
            ),
          ],
          if (extras.isNotEmpty) ...[
            const Gap(16),
            ...extras,
          ],
        ],
      ),
    );
  }
}
