# ShowSnap V2 — Animation Guide

## Entrance Animations (flutter_animate)

Standard pattern for screen content:

```dart
Widget()
  .animate()
  .fadeIn(duration: ShowSnapDuration.normal)
  .slideY(begin: 0.06, end: 0)
```

For staggered lists, add a delay multiplied by index:

```dart
Widget()
  .animate()
  .fadeIn(duration: ShowSnapDuration.normal,
          delay: Duration(milliseconds: 150 * index))
  .slideY(begin: 0.06, end: 0,
          delay: Duration(milliseconds: 150 * index))
```

For large lists (>8 items), prefer `flutter_staggered_animations`:

```dart
AnimationLimiter(
  child: ListView.builder(
    itemBuilder: (context, index) =>
      AnimationConfiguration.staggeredList(
        position: index,
        duration: const Duration(milliseconds: 250),
        child: SlideAnimation(
          verticalOffset: 40,
          child: FadeInAnimation(child: YourWidget()),
        ),
      ),
  ),
)
```

## Tappable Scale (TappableScale)

Wrap any interactive card or button with `TappableScale`:

```dart
TappableScale(
  onTap: () { /* ... */ },
  enableHaptic: true, // default: true
  child: YourCard(),
)
```

It scales to 0.95 on press-down (100ms) and springs back (150ms).
`HapticFeedback.lightImpact()` fires on tap-up.
Automatically disabled when `MediaQuery.disableAnimations` is true.

## Page Transitions (GoRouter)

| Route type          | Transition                | Helper          |
|---------------------|---------------------------|-----------------|
| Tab navigation      | FadeScale                 | `_fadePage`     |
| Drill-down (movie)  | SharedAxis horizontal     | `_horizontalPage` |
| Modal / bottom sheet| SharedAxis vertical       | `_verticalPage` |

Duration for all page transitions: `ShowSnapDuration.page` (450ms).

## Hero Transitions

Tag pattern: `movie_poster_<movieId>`

Apply the same tag to the `CachedNetworkImage` in both the card (source) and the detail screen (destination). Wrap with `Hero()` — not the outer container.

## Confetti (confetti package)

```dart
final _confetti = ConfettiController(duration: Duration(seconds: 2));

// Fire after entrance animation completes
Future.delayed(Duration(milliseconds: 700), () {
  if (mounted) _confetti.play();
});

// In build:
ConfettiWidget(
  confettiController: _confetti,
  blastDirectionality: BlastDirectionality.explosive,
  colors: [ShowSnapColors.primary, ShowSnapColors.secondary, Colors.white],
  numberOfParticles: 40,
  gravity: 0.1,
)
```

Always dispose: `_confetti.dispose()` in `dispose()`.

## Seat Selection Animations

- **Screen bar**: scaleX 0.6 → 1.0, elasticOut, 500ms on mount
- **Seat rows**: staggered SlideAnimation (horizontal -30) + FadeInAnimation, 250ms, via AnimationLimiter
- **Individual seat toggle**: TweenSequence scale 1.0 → 1.3 → 0.9 → 1.0, 300ms, triggered in `didUpdateWidget` when `isSelected` changes
- **Timer chip color**: AnimatedContainer, green (>4min) → orange (2–4min) → red (<2min)

## Splash Screen

```
200ms  — logo scale 0.4 → 1.0, elasticOut, 800ms total
600ms  — "ShowSnap" text slideY + fadeIn, 500ms easeOutCubic
900ms  — tagline fadeIn
1400ms — loading bar width 0 → 100%, 1000ms linear
2700ms — navigate
```

## Reduced Motion

Check `MediaQuery.of(context).disableAnimations` before firing haptics or animations in custom widgets. `TappableScale` handles this automatically. For `flutter_animate`, the library respects the system accessibility setting by default when `Animate.defaultDuration` is not overridden.
