# Liquid Glass Complete Color & Typography Token Mapping

## 1. Full Distinct Hard-Coded Colors Table

| Occurrences | Raw Pattern | Primary Semantic Token Mapping |
| :--- | :--- | :--- |
| **561** | `AppColors.primary` / `Colors.primary` | `context.glass.primary` |
| **372** | `AppColors.lightSecondaryText` | `context.glass.textSecondary` |
| **323** | `Colors.white` | `context.glass.textPrimary` (dark) / `cardFill` / `textOnPrimary` |
| **229** | `AppColors.success` / `Color(0xFF16A36A)` | `context.glass.success` |
| **142** | `AppColors.lightMutedText` | `context.glass.textSecondary` |
| **133** | `AppColors.lightPrimaryText` | `context.glass.textPrimary` |
| **127** | `Colors.grey` / `Colors.grey.shade300` | `context.glass.textSecondary` / `context.glass.cardBorder` |
| **120** | `AppColors.lightInputBackground` | `context.glass.searchFill` |
| **97** | `AppColors.darkPrimaryText` | `context.glass.textPrimary` |
| **96** | `AppColors.error` / `Color(0xFFEF4444)` | `context.glass.error` |
| **83** | `Colors.red` / `Color(0xFFDC2626)` | `context.glass.error` |
| **78** | `Colors.green` / `Color(0xFF10B981)` | `context.glass.success` |
| **69** | `AppColors.darkSecondaryText` | `context.glass.textSecondary` |
| **60** | `AppColors.primary.withOpacity(...)` | `context.glass.headerIconTileFill` |
| **54** | `AppColors.darkMainSurface` | `context.glass.cardFill` |
| **53** | `AppColors.lightPrimary` | `context.glass.activeTabFill` |
| **51** | `AppColors.warning` / `Color(0xFFF59E0B)` | `context.glass.warning` |
| **47** | `AppColors.darkSecondarySurface` | `context.glass.cardFill` |
| **45** | `Colors.blue` / `Color(0xFF2563EB)` | `context.glass.info` |
| **44** | `AppColors.lightBordersAndDividers` | `context.glass.cardBorder` |
| **43** | `AppColors.darkBordersAndDividers` | `context.glass.cardBorder` |
| **41** | `AppColors.successBg` | `context.glass.successTint` |
| **37** | `Colors.orange` / `Color(0xFFFB923C)` | `context.glass.warning` |
| **35** | `Colors.grey.shade200` | `context.glass.cardBorder` |
| **31** | `Color(0xFF2563EB)` | `context.glass.info` |
| **30** | `Colors.purple` / `Color(0xFF818CF8)` | `context.glass.pending` |

---

## 2. Colors Usage-Site Mapping Table (`Value x Usage-Site -> Token`)

| Color Pattern | Usage Site Context | Mapped Semantic Token |
| :--- | :--- | :--- |
| `Colors.white` | TextStyle / Icon on filled/gradient button | `context.glass.textOnPrimary` |
| `Colors.white` | Container / Card / Modal Background | `context.glass.cardFill` / `context.glass.headerFill` |
| `Colors.white` | Page / Scaffold Background | `context.glass.backgroundGradientColors` (via `AppBackground`) |
| `Colors.grey` / `AppColors.lightSecondaryText` | Primary Body / Headline Text | `context.glass.textPrimary` |
| `Colors.grey` / `AppColors.lightMutedText` | Subtitle / Caption / Timestamp Text | `context.glass.textSecondary` |
| `Colors.grey.shade300` / `AppColors.lightBorderSubtle` | Container Border / Divider Line | `context.glass.cardBorder` |
| `AppColors.success` / `Colors.green` | Status Badge Container Fill | `context.glass.successTint` |
| `AppColors.success` / `Colors.green` | Status Badge Text / Icon | `context.glass.successText` |
| `AppColors.warning` / `Colors.amber` | Status Badge Container Fill | `context.glass.warningTint` |
| `AppColors.warning` / `Colors.amber` | Status Badge Text / Icon | `context.glass.warningText` |
| `AppColors.error` / `Colors.red` | Status Badge Container Fill | `context.glass.errorTint` |
| `AppColors.error` / `Colors.red` | Status Badge Text / Icon | `context.glass.errorText` |
| `AppColors.info` / `Colors.blue` | Status Badge Container Fill | `context.glass.infoTint` |
| `AppColors.info` / `Colors.blue` | Status Badge Text / Icon | `context.glass.infoText` |
| `Color(0xFF6366F1)` / `Colors.indigo` | Status Badge Container Fill | `context.glass.pendingTint` |
| `Color(0xFF6366F1)` / `Colors.indigo` | Status Badge Text / Icon | `context.glass.pendingText` |

---

## 3. Font Size Mapping Table (Preserving `fontWeight`, `color`, `height` via `copyWith`)

| Original `fontSize:` | Nearest Existing Scale Token | Usage Context |
| :--- | :--- | :--- |
| `fontSize: 10` | `Theme.of(context).textTheme.bodySmall` (10px) | Micro Timestamps & Caption Badges |
| `fontSize: 11` | `Theme.of(context).textTheme.bodySmall` (11px / 700) | Section Labels, Compact Badges |
| `fontSize: 12` | `Theme.of(context).textTheme.bodyMedium` (12px / 500) | Card Subtitles, Secondary Text |
| `fontSize: 13` | `Theme.of(context).textTheme.titleMedium` (13px / 600) | Table Content, Compact Titles |
| `fontSize: 14` | `Theme.of(context).textTheme.bodyMedium` (14px) | Form Field Input Text |
| `fontSize: 15` | `Theme.of(context).textTheme.bodyLarge` (15px / 500) | Main Card Titles, Form Field Inputs |
| `fontSize: 16` | `Theme.of(context).textTheme.titleLarge` (15px/16px) | Section Headers, Primary Buttons |
| `fontSize: 18` | `Theme.of(context).textTheme.headlineMedium` (18px / 800) | Sub-Screen Titles, Modal Headers |
| `fontSize: 20` | `Theme.of(context).textTheme.headlineLarge` (20px / 800) | Screen Titles, Main KPI Values |
| `fontSize: 26+` | `Theme.of(context).textTheme.headlineLarge.copyWith(...)` | Giant Clock / Timer Displays |
