# Modernize Swift popups

## Goal
Make every Swift popup feel consistent and remain fully visible above rounded device edges and the home indicator, including challenge and badge details.

## Changes
- Add one reusable popup presentation style with a visible drag handle, consistent rounded top corners/background, safe-area spacing, and adaptive sizing.
- Replace rigid fixed-height challenge and badge popups with scrollable, content-fitting sheets that can expand on smaller devices or larger text sizes.
- Apply the same presentation style to popups opened from Home, Challenges, Statistics, Profile, Parent, Coach, Settings, authentication, and Legal screens.
- Keep all current wording, actions, navigation, colors, and functionality unchanged.

## Technical details
- Use a shared SwiftUI view modifier for presentation chrome and safe-area behavior.
- Put long or keyboard-sensitive popup content in a scrollable container and retain action controls within the visible safe area.
- Prefer adaptive detents (`medium`/`large`) over device-fragile pixel heights, with background interaction disabled while a popup is open.
- Verify all Swift popup call sites use the shared treatment and run the available project checks.
