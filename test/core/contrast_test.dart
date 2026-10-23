import 'package:aelos/core/theme/aelos_colors.dart';
import 'package:aelos/domain/models/condition_status.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  for (final (name, c) in [('light', AelosColors.light), ('dark', AelosColors.dark)]) {
    group('$name mode contrast', () {
      final grounds = {'background': c.background, 'surface': c.surface};

      void check(String label, Color fg, double min) {
        for (final MapEntry(key: ground, value: bg) in grounds.entries) {
          final ratio = _contrast(Color.alphaBlend(fg, bg), bg);
          expect(ratio, greaterThanOrEqualTo(min), reason: '$label on $ground: $ratio');
        }
      }

      test('text is at least 4.5:1', () {
        check('text', c.text, 4.5);
        check('textMuted', c.textMuted, 4.5);
        check('accentInk', c.accentInk, 4.5);
        for (final s in ConditionStatus.values) {
          check('${s.name} ink', c.statusInk(s), 4.5);
        }
      });

      test('marks and faint text are at least 3:1', () {
        check('textFaint', c.textFaint, 3);
        check('accent', c.accent, 3);
        for (final s in ConditionStatus.values) {
          check('${s.name} mark', c.status(s), 3);
        }
      });

      test('status ink stays at least 4.5:1 on its own tint', () {
        for (final s in ConditionStatus.values) {
          for (final MapEntry(key: ground, value: bg) in grounds.entries) {
            final tint = Color.alphaBlend(c.statusTint(s), bg);
            final ratio = _contrast(c.statusInk(s), tint);
            expect(ratio, greaterThanOrEqualTo(4.5), reason: '${s.name} on tint over $ground: $ratio');
          }
        }
      });
    });
  }
}
