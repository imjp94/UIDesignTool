# Changelog

## 0.2.1

- Bugfixes:
  - Fix null exception when selected non-`Control` node

## 0.2.0

- Features:
  - Batch edit
  - Support vertical align
- Improvements:
  - Support highlighting `Panel`/`PanelContainer`
  - Font resources only loaded after toolbar first shows up
  - Move user preferences from plugin.cfg to user_pref.cfg(Avoid preferences being overwrited after updates)
  - UI
    - Position `Popup` near to their trigger button
    - Replace Font Weight list with Bold as `PopupMenuButton`
    - Makes `OptionButton` width fixed
    - Group horizontal align into one `PopupMenu`
    - Group Font Family File Dialog & Font Family Refresh into one `PopupMenu`
    - Group Font Clear, Color Clear & Rect Size Refresh to one `PopupMenu`
- Bugfixes:
  - Unable to recognize font data from saved scene
  - Highlight/Font color auto applied white color even without picking any color after `ColorPicker` close
  - Font color can't be reset
  - Unable to assign `Color(0, 0, 0)` to font

## 0.1.1

- Fix unable to set Color(0, 0, 0) to font
- Organize screenshots to "screenshots/"

## 0.1.0

- Initial release
- Import and manage TrueType fonts(.ttf)
- Edit text directly in editor viewport
- Basic styling operations:
  - Font type
  - Font weight
  - Font size
  - Font color
  - Highlight
  - Horizontal alignment
  - Font Style/Formatting(Typography hierarchy)
  - Clear font
  - Clear color
  - Rect size refresh
