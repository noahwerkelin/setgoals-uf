# Show the Friends card on the iPhone Profile

The iPhone Friends card (search, requests, accept/decline, remove with the "×" button) exists but is never placed on the Profile page — Profile only shows the photo card and the embedded statistics.

## Change
- In `ios/SetGoals/Features/Profile/ProfileView.swift`, add `FriendsCard()` to the main stack directly below the profile photo card and above the statistics, matching the web Profile.
- No styling, data or text changes; the card already uses the shared preloaded friends data, so it appears instantly.

## Result
Profile shows your friends, pending requests, the Add button, and the "×" to remove a friend.
