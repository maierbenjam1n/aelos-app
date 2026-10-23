import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/tokens.dart';

extension RiseIn on Widget {
  /// Fades in while rising 14 px, delayed by [index] × [Motion.stagger] so
  /// cards arrive in sequence.
  Widget riseIn(int index) => animate(delay: Motion.stagger * index)
      .fadeIn(duration: Motion.slow, curve: Motion.enter)
      .moveY(begin: 14, end: 0, duration: Motion.slow, curve: Motion.enter);
}
