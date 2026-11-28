import 'package:bull_ui/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

/// The Bull Bitcoin mark, painted as four separate
/// shapes and refilled in a staggered cascade.
///
/// Only the loading splash uses it. The mark is decorative: it carries no
/// text, and it is excluded from the semantics tree so screen readers and UI
/// automation see the loading copy instead of an unlabelled graphic.
///
/// The artwork is maintained in this package, not generated from anywhere:
/// `assets/splash/bb-mark-{tl,tr,bl,br}.svg` hold one shape each, with the
/// source `viewBox` (`0 0 2975 2512`) and the source `d` value verbatim, so no
/// path is ever retyped here. The files carry no fill — the colour comes from
/// the theme ([AppColors.markFixed]). The two Android launch-screen vectors
/// (`res/drawable/splash_mark.xml` and `splash_mark_android12.xml`) repeat the
/// same four `d` values, and `test/ui/splash_mark_geometry_test.dart` fails if
/// the copies drift apart.
class SplashMark extends StatefulWidget {
  /// Creates the animated mark at [height] logical pixels tall.
  const SplashMark({super.key, this.height = 127});

  /// Height of the *mark* box, not of its source canvas.
  ///
  /// 127 dp is the size this splash uses on a 390 dp wide stage, and what the
  /// pre-Android 12 launch vector repeats.
  final double height;

  /// Width of the mark for a given [height], from the source `viewBox`.
  static const double aspectRatio = 2975 / 2512;

  /// One full cascade: a 0.95 s linear cycle.
  static const Duration cycleDuration = Duration(milliseconds: 950);

  /// Per-shape offsets into the cycle: 0 / 50 / 100 / 150 ms, in
  /// `tl, tr, bl, br` order.
  static const List<double> shapeDelays = <double>[0, 1 / 19, 2 / 19, 3 / 19];

  /// A shape stays transparent from 0 % to 15.79 % of its own timeline.
  static const double transparentUntil = 0.1579;

  /// A shape is fully filled from 17.54 % of its own timeline.
  static const double filledFrom = 0.1754;

  /// Where a running cycle starts.
  ///
  /// The native launch screen shows the fully filled static mark, so the first
  /// Flutter frame has to show it too: at 0.35 every shape is past its own
  /// 15.79–17.54 % fade window. Starting at 0 would blink an empty page for
  /// the first 316 ms of the transition instead.
  static const double startAt = 0.35;

  /// Fill opacity of [shape] (`0` = `tl`, `1` = `tr`, `2` = `bl`, `3` = `br`)
  /// when the cycle is at [cycleValue] (0 to 1).
  ///
  /// Each shape animates on its own timeline, offset by its delay, and is
  /// transparent until its own 15.79 % keyframe. A shape that has not started
  /// yet stays transparent rather than showing its filled state early.
  static double fillAt(int shape, double cycleValue) {
    final double local = cycleValue - shapeDelays[shape];
    if (local < 0) return 0;
    final double phase = local % 1.0;
    return ((phase - transparentUntil) / (filledFrom - transparentUntil)).clamp(
      0.0,
      1.0,
    );
  }

  @override
  State<SplashMark> createState() => _SplashMarkState();
}

class _SplashMarkState extends State<SplashMark>
    with SingleTickerProviderStateMixin {
  static const String _package = 'onboarding';

  /// `tl, tr, bl, br`: the order [SplashMark.shapeDelays] and
  /// [SplashMark.fillAt] use.
  static const List<String> _assets = <String>[
    'assets/splash/bb-mark-tl.svg',
    'assets/splash/bb-mark-tr.svg',
    'assets/splash/bb-mark-bl.svg',
    'assets/splash/bb-mark-br.svg',
  ];

  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: SplashMark.cycleDuration,
  );

  /// Whether the platform asks for reduced motion. `null` until the first
  /// [didChangeDependencies], so the first build always takes the decision.
  bool? _reducedMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyMotionPreference(
      MediaQuery.disableAnimationsOf(context) ||
          MediaQuery.reduceMotionOf(context),
    );
  }

  void _applyMotionPreference(bool reduced) {
    if (_reducedMotion == reduced) return;
    _reducedMotion = reduced;
    if (reduced) {
      _cycle.stop();
      return;
    }
    // Restart from the filled hand-off frame: the setting can be turned off
    // while the splash is on screen.
    _cycle.value = SplashMark.startAt;
    _cycle.repeat();
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color markColor = context.appColors.markFixed;
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.height * SplashMark.aspectRatio,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _cycle,
          builder: (context, _) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              for (int i = 0; i < _assets.length; i++)
                Opacity(
                  // `== true` rather than a `?? false` fallback: before the
                  // first [didChangeDependencies] the preference is unknown,
                  // and the animation is then the honest state to paint.
                  opacity: _reducedMotion == true
                      ? 1
                      : SplashMark.fillAt(i, _cycle.value),
                  child: SvgPicture.asset(
                    _assets[i],
                    package: _package,
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                    colorFilter: ColorFilter.mode(markColor, BlendMode.srcIn),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
