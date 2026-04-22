import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/error_reporting_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/language_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/theme_step.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_dots.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/wizard_page.dart';
import 'package:bb_mobile/features/wizard/wizard_choices.dart';
import 'package:flutter/material.dart';

class WizardScreen extends StatefulWidget {
  const WizardScreen({
    super.key,
    required this.choices,
    required this.onChange,
    required this.onDone,
  });

  final WizardChoices choices;
  final ValueChanged<WizardChoices> onChange;
  final VoidCallback onDone;

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const Duration _pageDuration = Duration(milliseconds: 300);
  static const Curve _pageCurve = Curves.easeInOut;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(int stepCount) {
    if (_page < stepCount - 1) {
      _controller.nextPage(duration: _pageDuration, curve: _pageCurve);
    } else {
      widget.onDone();
    }
  }

  void _back() {
    if (_page > 0) {
      _controller.previousPage(duration: _pageDuration, curve: _pageCurve);
    }
  }

  List<_Step> _buildSteps(BuildContext context) {
    final c = widget.choices;
    return [
      _Step(
        title: context.loc.settingsThemeTitle,
        image: 'assets/wizard/undraw_insert-block.svg',
        child: ThemeStep(
          selected: c.themeMode,
          onChanged: (v) => widget.onChange(c.copyWith(themeMode: v)),
        ),
      ),
      _Step(
        title: context.loc.settingsLanguageTitle,
        image: 'assets/wizard/undraw_global-team.svg',
        child: LanguageStep(
          selected: c.language,
          onChanged: (v) => widget.onChange(c.copyWith(language: v)),
        ),
      ),
      _Step(
        title: context.loc.errorReportingProgramTitle,
        image: 'assets/wizard/undraw_upload-warning.svg',
        child: ErrorReportingStep(
          enabled: c.errorReporting,
          onChanged: (v) => widget.onChange(c.copyWith(errorReporting: v)),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps(context);
    final isLast = _page == steps.length - 1;

    return Scaffold(
      appBar: AppBar(title: Text(steps[_page].title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: steps
                    .map((s) => WizardPage(image: s.image, child: s.child))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            WizardDots(count: steps.length, index: _page),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BBButton.big(
                    label: isLast
                        ? context.loc.getStartedButton
                        : context.loc.continueButton,
                    onPressed: () => _next(steps.length),
                    bgColor: context.appColors.primary,
                    textColor: context.appColors.onPrimary,
                  ),
                  const SizedBox(height: 12),
                  IgnorePointer(
                    ignoring: _page == 0,
                    child: Opacity(
                      opacity: _page == 0 ? 0 : 1,
                      child: BBButton.big(
                        label: context.loc.backButton,
                        onPressed: _back,
                        bgColor: context.appColors.surface,
                        textColor: context.appColors.text,
                        borderColor: context.appColors.border,
                        outlined: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  const _Step({
    required this.title,
    required this.image,
    required this.child,
  });

  final String title;
  final String image;
  final Widget child;
}
