# UI Button/Input Fix

## Fixed

- Added `ui/interactive_button.gd` as a shared input-safe Button behavior.
- All dynamically created UI buttons from `UIKit.make_button()` now explicitly use `MOUSE_FILTER_STOP`, keyboard/gamepad focus, and `PROCESS_MODE_ALWAYS`.
- Main menu buttons now have explicit handlers and are forced visible/interactive.
- Main menu background now ignores mouse input so it cannot block the buttons.
- Tutorial buttons (`OK`, `NEXT`, and the interaction button) now use the shared interactive button behavior.
- Tutorial decorative labels/overlay ignore mouse input.
- Pause, Game Over, Level Complete, and Controls buttons inherit the shared input-safe behavior through `UIKit`.
- Pause/Game Over/Level Complete/Controls force the mouse cursor visible.
- The transition screen's full-screen fade no longer captures mouse input. This was the major blocker for buttons on gameplay overlays because the transition layer is above them (layer 100).

## Design

UI input ownership is now explicit:

- Decorative/full-screen visuals: `MOUSE_FILTER_IGNORE`
- Containers: `MOUSE_FILTER_PASS`
- Actual buttons: `MOUSE_FILTER_STOP`

The existing game logic and button callbacks are preserved.
