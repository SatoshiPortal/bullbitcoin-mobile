import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/template/screen_template.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ProgressScreen extends StatelessWidget {
  final String? title;
  final String? description;
  final List<Widget> extras;
  final bool isLoading;
  final VoidCallback? onTap;
  final String? buttonText;

  const ProgressScreen({
    super.key,
    this.title,
    this.description,
    this.extras = const [],
    this.isLoading = true,
    this.onTap,
    this.buttonText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.onSecondary,
      body: StackedPage(
        bottomChildHeight: MediaQuery.of(context).size.height * 0.2,
        bottomChild: (!isLoading && onTap != null)
            ? BBButton.big(
                label: buttonText ?? 'Continue',
                onPressed: onTap ?? () {},
                textColor: context.colour.onPrimary,
                bgColor: context.colour.secondary,
              )
            : const SizedBox.shrink(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: isLoading
                    ? Image.network(
                        "https://s3-alpha-sig.figma.com/img/8bc4/c05f/a9d95a1e4eb48bca4e89c563d5a731a1?Expires=1744588800&Key-Pair-Id=APKAQ4GOSFWCW27IBOMQ&Signature=mzHul7JycaOyzgh1Xx3FGcoUj9Hbg4vjRQIYTfvyzFwLzPZkX4aAKXvrUiTkeYX-fV8kPJDWkBi3z3YDuzK-Q80widmpuIPGgVYuKDGVD~6p-sN8D7yy-QNEjCh3G3BDvSSaWigX2KBJTQqbjKkBNORlkdgUA~iw7TL8GLz0s~0VyYO5aEnBBWlfBwRZjfeZZhKSe8tOAzQr5FEIHewYBI91tFQfaxSe6ps155kIXbDTDH-IwwhSQDx1y0iuFTo6BuzXMnCIeMayrHpWhKkqjTKa~6PiRD9KTDbseQPMpbWTBZnHlseL3yXDjN~8YGx32hLz7athKI5Zpq6d10fKaw__",
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : const SizedBox.shrink(),
              ),
              if (title == null)
                const SizedBox.shrink()
              else
                BBText(
                  textAlign: TextAlign.center,
                  style: context.font.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  title ?? '',
                ),
              const Gap(16),
              if (description == null)
                const SizedBox.shrink()
              else
                BBText(
                  description ?? '',
                  textAlign: TextAlign.center,
                  style: context.font.bodySmall,
                  maxLines: 3,
                ),
              if (extras.isNotEmpty) ...[
                const Gap(16),
                ...extras,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
