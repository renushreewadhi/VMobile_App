# Non-BuildContext Color Usage Manual Review List

This file tracks static constants, model helpers, enums, top-level utilities, and chart series colors that cannot automatically receive a `BuildContext`. They must be updated manually or refactored to accept `BuildContext` or resolve tokens via `Theme.of(context)`.

## 1. Top-Level / Static Constant Colors
- `lib/core/theme/app_colors.dart` (Lines 5-67): Legacy palette constants maintained for backwards compatibility during migration.
- `lib/employee/screens/my_attendance_screen.dart` (Lines 30-33): Static section indicator colors (`_purple`, `_green`, `_red`, `_amber`).
- `lib/employee/screens/more_screen.dart` (Lines 110-380): Module item gradient arrays in `ParentModuleItem` and `SubModuleItem` data models.

## 2. Models & Data Classes
- `lib/core/models/user_model.dart`: Role string formatters and status helpers.
- `lib/shared/widgets/compact_summary_widgets.dart`: Hard-coded indicator colors for metric sparklines.

## 3. Charts & Visualizations (`fl_chart`)
- `lib/finance/screens/finance_dashboard_screen.dart`: Pie/Bar chart section colors.
- `lib/employee/screens/my_performance_screen.dart`: Line chart series colors.
