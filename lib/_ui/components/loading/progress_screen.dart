import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
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
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Center(
                child: isLoading
                    ? Image.network(
                        "https://s3-alpha-sig.figma.com/img/8bc4/c05f/a9d95a1e4eb48bca4e89c563d5a731a1?Expires=1743379200&Key-Pair-Id=APKAQ4GOSFWCW27IBOMQ&Signature=myGDtu84V4GK2t7tVds~kU5wFPWTeWVzDMGsT0uaM85y6bI9HWRkTzZ6KHUVGqVjk4Idi58QobhqJ7ZvY-3Hr~41DOWJkec-hTQGp~sXYJgDa7ZG3teaIyGdDZynf0BQLEDHqh8x~3tSl3YM-S-BiklqpxldGSbLo989DdTpBDJdY12l8U8CSaG7HsxpY4Ttlm4H0ygg4P0WI0qCHkV-70yUvTgBdQTkwMg1pRhlKII8acDeBy1kYhh-kEJPi92Io-qcstvsXUf7LuRFYEzhDVQCvs3Oy8RDRu-0P2UMpiFO36Vu~1YlITO~ffn8rUjsrvWjt0J97ko1-lC7wXVgJw_",
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : const Icon(
                        Icons.check_circle_outline,
                        size: 100,
                      ),
              ),
              const Gap(32),
              if (title == null)
                const SizedBox.shrink()
              else
                BBText(
                  title ?? '',
                  textAlign: TextAlign.center,
                  style: context.font.headlineLarge,
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
              if (!isLoading && onTap != null) ...[
                const Gap(32),
                BBButton.big(
                  label: buttonText ?? 'Continue',
                  onPressed: onTap ?? () {},
                  textColor: context.colour.onPrimary,
                  bgColor: context.colour.secondary,
                ),
              ],
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
