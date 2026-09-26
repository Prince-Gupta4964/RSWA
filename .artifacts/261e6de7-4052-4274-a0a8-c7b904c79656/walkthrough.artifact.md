# Transparent Sticky Navigation Background

I have removed the background container box and shadow behind the sticky bottom navigation buttons across the main forms (`AddProjectView`, `AddCPView`, and `AddLeadView`).

## Key Changes

### Form Views (`AddProjectView.dart`, `AddCPView.dart`, `AddLeadView.dart`)
- **Transparent Background**: Set `decoration: const BoxDecoration(color: Colors.transparent)` on the sticky navigation container.
- Removed the white container fill and drop shadow so that the navigation buttons (`←`, `Save / Update`, `→`) float cleanly over the page background without any background box behind them.

## Verification
- Analyzed all updated form views with **zero compilation errors**.
- Verified that form navigation buttons render cleanly on transparent backgrounds.
