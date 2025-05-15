# Design Guidelines: Twogether Web App

This document outlines the design principles, visual styles, and UI component guidelines for the Twogether web application, aiming for a professional, clean, and intuitive user experience inspired by Apple's design language.

## 1. Core Philosophy & Principles

*   **Clarity:** Text should be legible, icons precise, and adornment unobtrusive. UI elements and interactions should be easy to understand.
*   **Deference:** The UI should help users understand and interact with their content without competing with it. The focus is on the user's tasks and data.
*   **Depth:** Visual layers, subtle shadows, and realistic motion can be used to convey hierarchy, importance, and a sense of place within the application.
*   **Professionalism:** The app should feel polished, reliable, and trustworthy through clean layouts, consistent styling, and attention to detail.
*   **Simplicity & Intuitiveness:** The application should be easy to learn and efficient to use. Minimize complexity and cognitive load.

## 2. Color Palette

This section reflects the colors defined in `lib/core/theme/theme.dart`.

**Shared:**
*   `destructive`: `#E94E4E` (Foreground: `#F2F7FD` for light, `#E0E0E0` for dark)

**Light Theme Colors:**
*   `background`: `#FFFFFF`
*   `foreground`: `#0A0E17` (Primary text)
*   `primary`: `#1A2337` (Primary actions, e.g., button background)
*   `primaryForeground`: `#F2F7FD` (Text on primary elements)
*   `secondary`: `#F4F7FB` (Secondary surfaces/elements)
*   `secondaryForeground`: `#1A2337` (Text on secondary elements)
*   `muted`: `#F4F7FB`
*   `mutedForeground`: `#687083` (Secondary/less prominent text)
*   `accent`: `#F4F7FB` (Note: Same as `secondary` in current theme)
*   `accentForeground`: `#1A2337` (Note: Same as `secondaryForeground` in current theme)
*   `border`: `#E5EAF0`
*   `input`: `#E5EAF0` (Input field background)
*   `ring`: `#0A0E17` (Focus indicator, less common)
*   `success`: `#22C55E` (e.g., `Color(0xFF22C55E)`)
*   `warning`: `#F59E0B` (e.g., `Color(0xFFF59E0B)`)
*   `popoverBackground`: `#FFFFFF`
*   `lightGradientStart`: `#7CBAE3`
*   `lightGradientEnd`: `#E1F4FD`

**Dark Theme Colors:**
*   `darkBackground`: `#0A192F` (Deep dark blue)
*   `darkNavBarBackground`: `#061324` (Slightly darker blue for nav)
*   `darkForeground`: `#E0E0E0` (Light gray for text)
*   `darkPrimary`: `#60A5FA` (Lighter blue for primary actions)
*   `darkPrimaryForeground`: `#0A192F` (Dark blue text on primary)
*   `darkSecondary`: `#1E293B` (Dark grayish blue, used as general surface in dark theme)
*   `darkSecondaryForeground`: `#E0E0E0` (Light gray text on secondary)
*   `darkMuted`: `#334155` (Muted dark blue/gray)
*   `darkMutedForeground`: `#94A3B8` (Lighter muted text)
*   `darkAccent`: `#60A5FA` (Same as `darkPrimary` for accent)
*   `darkAccentForeground`: `#0A192F` (Dark text on accent)
*   `darkBorder`: `#1E293B` (Match `darkSecondary` for borders)
*   `darkInput`: `#1E293B` (Match `darkSecondary` for inputs)
*   `darkSuccess`: `#4ADE80` (e.g., `Color(0xFF4ADE80)`)
*   `darkWarning`: `#FBBF24` (e.g., `Color(0xFFFBBF24)`)
*   `darkDestructive`: `#F87171` (e.g., `Color(0xFFF87171)`)
*   `darkPopoverBackground`: `#1E293B`
*   `darkGradientStart`: `#2A4E72`
*   `darkGradientEnd`: `#3A6491`

**Additional Color Definitions (from `lib/core/theme/colors.dart` - `AppColors`)**

This set of colors provides alternative or supplementary definitions. Clarify usage context if overlapping with `AppTheme` colors.

*   **Primary Colors (`AppColors`):**
    *   `primary`: `#1976D2`
    *   `primaryLight`: `#42A5F5`
    *   `primaryDark`: `#1565C0`
*   **Neutral Colors (`AppColors`):**
    *   `charcoal`: `#2C2C2C`
    *   `silver`: `#757575`
    *   `lightGray`: `#F5F5F5`
    *   `white`: `#FFFFFF`
    *   `black`: `#000000`
*   **Status Colors (`AppColors`):**
    *   `success`: `#4CAF50`
    *   `warning`: `#FFA726`
    *   `error`: `#B00020`
    *   `info`: `#2196F3`
    *   `amber`: `Colors.amber` (Flutter's amber)
*   **Background Colors (`AppColors`):**
    *   `background`: `#F5F5F5`
    *   `surface`: `#FFFFFF`
    *   `surfaceDark`: `#121212`
*   **Gradient Colors (`AppColors`):**
    *   `gradientStart`: `#D4E0F7` (very soft light blue)
    *   `gradientMiddle`: `#B1CCF8` (soft sky blue)
    *   `gradientEnd`: `#9DB9F0` (light periwinkle blue)
*   **Alpha Variants (`AppColors`):**
    *   Provides utility functions `whiteWithOpacity(opacity)` and `blackWithOpacity(opacity)`.
    *   Defines common alpha variants for white (e.g., `whiteAlpha05` to `whiteAlpha90`) and black (e.g., `blackAlpha05` to `blackAlpha90`). These are useful for creating effects like glassmorphism or subtle overlays.

## 3. Typography

*   **Font Family:**
    *   Primary: `Inter` (as implemented via `GoogleFonts.interTextTheme()` in `theme.dart` and specified in `text_styles.dart`).
    *   Base Letter Spacing: `-0.5` (defined in `AppTextStyles._baseTextStyle`).
    *   Fallbacks: `Helvetica Neue`, `Arial`, `sans-serif`.
*   **Typographic Scale (from `lib/core/theme/text_styles.dart` - `AppTextStyles`):**
    *   **Display Styles:**
        *   `display1`: Font size `56px`, `FontWeight.bold`.
    *   **Heading Styles:**
        *   `h1`: Font size `32px`, `FontWeight.bold`.
        *   `h2`: Font size `24px`, `FontWeight.bold`.
        *   `h3`: Font size `20px`, `FontWeight.w600`, Color `AppTheme.foreground` (`#0A0E17`).
        *   `h4`: Font size `18px`, `FontWeight.w600`, Color `AppTheme.foreground` (`#0A0E17`).
    *   **Body Styles:**
        *   `body1`: Font size `16px`, `FontWeight.normal`.
        *   `body2`: Font size `14px`, `FontWeight.normal`.
    *   **Button Text Style:**
        *   `button`: Font size `16px`, `FontWeight.w600`, Letter spacing `0`.
    *   **Caption Text Style:**
        *   `caption`: Font size `12px`, `FontWeight.normal`.
*   **Line Height:**
    *   Approximately 1.4x to 1.6x the font size for body text to ensure readability (General guideline, not explicitly in theme files but good practice).
*   **Weights:**
    *   As specified in the typographic scale above. `Regular` (normal), `Semibold` (w600), and `Bold` are used.
    *   Avoid overly thin or heavy weights for general UI text.

## 4. Iconography

*   **Style:**
    *   Clean, simple, and universally understandable line icons (outlined style).
    *   Strive for a consistent stroke weight and visual style across all icons.
    *   Consider Flutter's built-in `Icons`. Supplement with a high-quality library like `Lucide Icons` or `Feather Icons` if necessary, ensuring style consistency.
*   **Size:**
    *   Define standard icon sizes (e.g., 16px, 20px, 24px).
    *   Ensure touch targets for interactive icons are at least 44x44px (or 48x48px) by using appropriate padding.
*   **Color:**
    *   Light Theme: Icons should typically use `foreground` (`#0A0E17`), `mutedForeground` (`#687083`), or `primary` (`#1A2337`) if interactive.
    *   Dark Theme: Icons should typically use `darkForeground` (`#E0E0E0`), `darkMutedForeground` (`#94A3B8`), or `darkPrimary` (`#60A5FA`) if interactive. The `IconThemeData` in dark theme defaults to `darkMutedForeground`.

## 5. Layout & Spacing

*   **Grid System:**
    *   Adopt an 8pt grid system. All dimensions, margins, and paddings should be multiples of 8px (or 4px for finer control).
*   **White Space (Negative Space):**
    *   Utilize generous white space to create a clean, uncluttered interface. This improves focus and readability.
*   **Consistency:**
    *   Standardize padding within components (e.g., cards, input fields) and spacing between elements.
    *   Example Spacing Scale (multiples of 8):
        *   `4px` (xs)
        *   `8px` (sm)
        *   `12px`
        *   `16px` (md)
        *   `24px` (lg)
        *   `32px` (xl)
        *   `40px`
        *   `48px`
*   **Alignment:**
    *   Ensure elements are consistently aligned. Left-alignment is standard for LTR text.

## 6. UI Components (Styling & Behavior)

*   **App Bar / Header:**
    *   Light Theme: Follows Material defaults, generally using `background` (`#FFFFFF`) and `foreground` (`#0A0E17`).
    *   Dark Theme: Defined with `darkBackground` (`#0A192F`) for background, `darkForeground` (`#E0E0E0`) for text/icons, and `0` elevation.
    *   Clear, legible title.
    *   Minimal, recognizable icons for actions.
*   **Buttons:**
    *   **General:** Corner radius `8.0px`. Minimum height `48px`.
    *   **ElevatedButton (Primary):**
        *   Light Theme: Background `primary` (`#1A2337`), Text `primaryForeground` (`#F2F7FD`).
        *   Dark Theme: Background `darkPrimary` (`#60A5FA`), Text `darkPrimaryForeground` (`#0A192F`).
    *   **TextButton (Secondary/Tertiary):**
        *   Light Theme: Text `primary` (`#1A2337`).
        *   Dark Theme: Text `darkPrimary` (`#60A5FA`).
    *   Padding: Ensure sufficient internal padding (e.g., 12px vertical, 20px horizontal - review `minimumSize` effects).
*   **Cards & Surfaces:**
    *   **General:** Rounded Corners `8.0px`. Elevation `0`.
    *   Light Theme: Background `background` (`#FFFFFF`), Border `border` (`#E5EAF0`).
    *   Dark Theme: Background `darkSecondary` (`#1E293B`), Border `darkBorder` (`#1E293B`).
    *   Shadows: The theme currently sets `elevation: 0` for cards. If shadows are desired, they need to be added (e.g., `BoxShadow(color: Colors.black.withAlpha((255 * 0.05).round()), blurRadius: 10, offset: Offset(0, 4))`).
*   **Input Fields (Text Fields, Selects):**
    *   **General:** Rounded corners `8.0px`. Filled style.
    *   Light Theme:
        *   Fill Color: `input` (`#E5EAF0`).
        *   Border Color: `border` (`#E5EAF0`).
        *   Focused Border: `primary` (`#1A2337`), width `2px`.
    *   Dark Theme:
        *   Fill Color: `darkInput` (`#1E293B`).
        *   Border Color: `darkBorder` (`#1E293B`), enabled border uses `darkBorder.withAlpha(128)`.
        *   Focused Border: `darkPrimary` (`#60A5FA`).
        *   Error Border: `darkDestructive` (`#F87171`).
        *   Content Padding: `EdgeInsets.symmetric(horizontal: 16, vertical: 16)`.
        *   Label Style: `darkMutedForeground` (`#94A3B8`).
        *   Hint Style: `darkMutedForeground` (`#94A3B8`).
    *   Clear label and placeholder text.
*   **Navigation (Side Navigation / Tabs):**
    *   Clear visual hierarchy for navigation items.
    *   Active state clearly indicated (e.g., background color, accent color text/icon).
    *   Sufficient spacing between items.
*   **Modals & Dialogs (Popups):**
    *   **General:** Rounded corners `8.0px`. Elevation `4` (for `PopupMenuTheme`).
    *   Light Theme: Background `popoverBackground` (`#FFFFFF`), Text `foreground` (`#0A0E17`).
    *   Dark Theme: Background `darkPopoverBackground` (`#1E293B`), Text `darkForeground` (`#E0E0E0`).
    *   Scrim overlay on background content.
    *   Clear title, message, and action buttons.
*   **Dropdown Menus:**
    *   **General:** Rounded corners `8.0px`.
    *   Light Theme: `popoverBackground` (`#FFFFFF`) for menu items. Input decoration uses `popoverBackground` fill and `border` (`#E5EAF0`).
    *   Dark Theme: `darkPopoverBackground` (`#1E293B`) for menu items. Input decoration uses `darkPopoverBackground` fill and `darkBorder` (`#1E293B`).
*   **Lists & Tables:**
    *   Clear separation between rows.
    *   Legible text and appropriate spacing.
    *   Hover states for interactive rows if applicable.

## 7. Imagery & Visuals

*   **Quality:** Use high-resolution, crisp images. Avoid pixelation.
*   **Style:** If using illustrations, they should match the overall clean, modern, and professional aesthetic.
*   **Placeholder States:** Design thoughtful empty states and loading indicators.

## 8. Interaction & Animation

*   **Purposeful Animation:** Animations should provide feedback, guide the user, or enhance the perception of performance. Avoid purely decorative or distracting animations.
*   **Subtlety & Speed:** Animations should be quick and subtle (e.g., 150-300ms).
*   **Transitions:** Smooth page transitions and element transitions.
*   **Feedback:** Interactive elements should provide immediate visual feedback on hover, focus, and press states.

## 9. Accessibility (A11y)

*   **Color Contrast:** Ensure text and interactive elements meet WCAG AA contrast ratios (4.5:1 for normal text, 3:1 for large text).
*   **Keyboard Navigation:** All interactive elements must be focusable and operable via keyboard.
*   **Screen Reader Support:** Use semantic HTML (or Flutter's semantics widgets) to provide meaning to screen readers. Provide `alt` text for images.
*   **Focus Indicators:** Ensure focus states are clearly visible.
*   **Touch Targets:** Ensure touch targets are adequately sized (minimum 44x44 CSS pixels).

## 10. Voice & Tone

*   **Clarity:** Use clear, simple, and direct language.
*   **Conciseness:** Be brief and to the point.
*   **Friendliness:** Maintain a helpful and approachable tone.
*   **Consistency:** Use consistent terminology throughout the application.

## 11. Responsive Design (from `lib/core/theme/responsive.dart`)

*   **Breakpoints:**
    *   `mobileBreakpoint`: `600px`
    *   `tabletBreakpoint`: `900px`
    *   `desktopBreakpoint`: `1200px`
*   **Screen Size Detection Utilities:**
    *   `Responsive.isMobile(context)`
    *   `Responsive.isTablet(context)`
    *   `Responsive.isDesktop(context)`
*   **Responsive Padding (`Responsive.getPadding(context)`):**
    *   Mobile: `EdgeInsets.all(16)`
    *   Tablet: `EdgeInsets.all(24)`
    *   Desktop: `EdgeInsets.all(32)`
*   **Responsive Font Sizes (`Responsive.getFontSize(context, baseFontSize)`):**
    *   Mobile: `baseFontSize * 0.9`
    *   Tablet: `baseFontSize`
    *   Desktop: `baseFontSize * 1.1`
*   **Responsive Value Selection (`Responsive.getValueForScreenSize<T>(...)`):**
    *   Utility to select different values for mobile, tablet (optional), and desktop.
*   **Common Sizing and Constraints (from `lib/core/theme/ui_styles.dart`):**
    *   `sidebarWidth`: `250.0px`
    *   `badgeSize`: `16.0px`
    *   `navBarHeight`: `84.0px`
*   **Common Paddings (from `lib/core/theme/ui_styles.dart`):**
    *   `standardCardPadding`: `EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0)`
    *   `contentPadding`: `EdgeInsets.all(24.0)`

---
*This document is a living guide and will be updated as the application evolves.* 