# core

The design system and app-wide plumbing. Build every screen from these pieces instead of raw colours, sizes or durations.

- `theme/tokens.dart`: brand palette, `Space`, `Radii`, `Motion` (durations and curves; no bounce anywhere).
- `theme/aelos_colors.dart`: `AelosColors.of(context)` gives semantic colours per brightness. Use `*Ink` for text, the plain status colour for icons and marks, and `statusTint` for fills. `test/core/contrast_test.dart` enforces WCAG ratios, so keep it green when you change colours.
- `theme/aelos_type.dart`: the Material `TextTheme` (Cormorant Garamond for headings, Inter for the rest) and `AelosText.of(context)` for readings (tabular figures), units, eyebrows and italic notes.
- `theme/aelos_theme.dart`: `AelosTheme.light` and `.dark`. `theme/theme_mode.dart` holds the light/dark switch.
- `widgets/`: `AelosCard`, `StatusBadge` (colour + icon + word, always), `ReadingValue` (count-up), `Eyebrow`, `Hairline`, `FHole` (motif; `FHolePainter.progress` draws it in), `.riseIn(i)` for staggered entrances, `RoleMotif` (line drawings for owner, renter and luthier) and `Monogram` (initials avatar).
- `config/app_config.dart`: `--dart-define` values.

To review visuals without a phone, render screens to `build/screens/`:
`fvm flutter test test/screenshots --update-goldens --dart-define=SCREENSHOTS=true`
