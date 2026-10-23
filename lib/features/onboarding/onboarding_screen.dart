import 'package:flutter/material.dart';

import '../../core/theme/aelos_colors.dart';
import '../../core/theme/aelos_type.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/eyebrow.dart';
import '../../core/widgets/f_hole.dart';
import '../../core/widgets/hairline.dart';
import '../../core/widgets/rise_in.dart';
import 'onboarding_art.dart';
import 'permissions_page.dart';

class _Story {
  const _Story(this.numeral, this.eyebrow, this.headline, this.body, this.art);

  final String numeral;
  final String eyebrow;
  final String headline;
  final String body;
  final OnboardingArtKind art;
}

const _stories = [
  _Story(
    'I',
    'Climate',
    'The climate\ninside the case',
    'Temperature and humidity, read gently and continuously, so you always '
        'know how your instrument is resting.',
    OnboardingArtKind.climate,
  ),
  _Story(
    'II',
    'Impacts',
    'Every knock,\nnoticed',
    'Bumps and falls are recorded the moment they happen, with the time and '
        'how hard.',
    OnboardingArtKind.impact,
  ),
  _Story(
    'III',
    'Provenance',
    'A history\nyou can prove',
    'Every reading is signed by the sensor. Share the record with a buyer, '
        'dealer or insurer, like a car’s service book.',
    OnboardingArtKind.seal,
  ),
];

/// Three illustrated pages and a permissions page, then [onFinished] hands
/// over to pairing. Reads the permission gateway from Riverpod, so it needs a
/// `ProviderScope` above it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinished,
    this.initialPage = 0,
  });

  final VoidCallback onFinished;

  /// Page to open on; 3 is the permissions page. For screenshots and tests.
  final int initialPage;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static final _pageCount = _stories.length + 1;
  late final _controller = PageController(initialPage: widget.initialPage);
  late int _page = widget.initialPage;

  bool get _onPermissions => _page == _stories.length;

  void _goTo(int page) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: Motion.slow,
        curve: Motion.emphasis,
      );
    }
  }

  void _next() => _onPermissions ? widget.onFinished() : _goTo(_page + 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final label = switch (_page) {
      2 => 'Get started',
      _ => 'Continue',
    };

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              showSkip: !_onPermissions,
              onSkip: () => _goTo(_stories.length),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pageCount,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) => i < _stories.length
                    ? _StoryPage(_stories[i], active: i == _page)
                    : PermissionsPage(active: i == _page),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                0,
                Space.page,
                Space.l,
              ),
              child: Column(
                children: [
                  AnimatedOpacity(
                    opacity: _onPermissions ? 0 : 1,
                    duration: Motion.medium,
                    child: _PageIndicator(
                      count: _stories.length,
                      page: _page,
                      colors: colors,
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: AnimatedSwitcher(
                        duration: Motion.medium,
                        switchInCurve: Motion.enter,
                        switchOutCurve: Motion.exit,
                        child: Text(label, key: ValueKey(label)),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.only(left: Space.page, right: Space.s),
        child: Row(
          children: [
            FHole(height: 20, color: colors.accent),
            const SizedBox(width: Space.s + 2),
            Text(
              'AELOS',
              style: AelosText.of(context).eyebrow
                  .copyWith(color: colors.text, fontSize: 12, letterSpacing: 4),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: showSkip ? 1 : 0,
              duration: Motion.medium,
              child: IgnorePointer(
                ignoring: !showSkip,
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.textMuted,
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage(this.story, {required this.active});

  final _Story story;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = AelosColors.of(context);
    final text = Theme.of(context).textTheme;
    final animate = active && !MediaQuery.disableAnimationsOf(context);
    final body = text.bodyLarge!.copyWith(color: colors.textMuted);

    final lines = <Widget>[
      Eyebrow('${story.numeral}  ·  ${story.eyebrow}', color: colors.accentInk),
      Padding(
        padding: const EdgeInsets.only(top: Space.m),
        child: Text(
          story.headline,
          style: text.displayMedium,
          textAlign: TextAlign.center,
        ),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.l + 2),
        child: SizedBox(width: 96, child: Hairline(ornament: true)),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        // The invisible three lines reserve the same height on every page, so
        // the headline doesn't shift as you swipe.
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Text('\n\n', style: body),
            Text(story.body, style: body, textAlign: TextAlign.center),
          ],
        ),
      ),
    ];

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.l,
              vertical: Space.s,
            ),
            // Sit the art nearer the text than the top bar, so they read as one.
            child: Align(
              alignment: const Alignment(0, 0.35),
              child: AspectRatio(
                aspectRatio: 1,
                child: OnboardingArt(kind: story.art, active: active),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.page,
            Space.l,
            Space.page,
            Space.xxl,
          ),
          child: Column(
            children: [
              for (final (i, line) in lines.indexed)
                animate
                    ? line.riseIn(i)
                    : Opacity(opacity: active ? 1 : 0, child: line),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.page,
    required this.colors,
  });

  final int count;
  final int page;
  final AelosColors colors;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Page ${page + 1} of $count',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.medium,
            curve: Motion.emphasis,
            margin: const EdgeInsets.symmetric(horizontal: Space.xs - 1),
            width: i == page ? 28 : 14,
            height: 1.5,
            color: i == page
                ? colors.accent
                : colors.textFaint.withValues(alpha: 0.45),
          ),
      ],
    ),
  );
}
