import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A reusable input field widget that uses the exact InputDecoration style from admin_salesforce_proposal_detail_page.dart.
class AppInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool readOnly;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final TextStyle? labelStyle;

  const AppInputField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.readOnly = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.maxLines,
    this.minLines,
    this.onChanged,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    InputDecoration inputDecoration() {
      return InputDecoration(
        labelText: label,
        labelStyle: labelStyle ?? textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        hintText: hint,
        hintStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
        ),
        filled: true,
        fillColor: readOnly
            ? colorScheme.surfaceContainerHighest.withAlpha((255 * 0.7).round())
            : colorScheme.surfaceContainerHighest,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.2).round())),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.08).round())),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: suffixIcon,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      );
    }

    return SizedBox(
      height: 56,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines ?? 1,
        minLines: minLines ?? 1,
        readOnly: readOnly,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
        decoration: inputDecoration().copyWith(
          hintText: (controller.text.isEmpty) ? '' : hint,
        ),
      ),
    );
  }
}

class AppDateInputField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? hint;
  final bool readOnly;
  final String? Function(DateTime?)? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final TextStyle? labelStyle;

  const AppDateInputField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.readOnly = false,
    this.validator,
    this.firstDate,
    this.lastDate,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final controller = TextEditingController(
      text: value != null ?
        DateFormat('dd/MM/yyyy', 'pt_PT').format(value!) : '',
    );

    Future<void> pickDate() async {
      if (readOnly) return;
      
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: firstDate ?? DateTime(1900),
        lastDate: lastDate ?? DateTime(2101),
        locale: const Locale('pt', 'PT'),
        helpText: 'Selecionar data',
        cancelText: 'Cancelar',
        confirmText: 'OK',
        fieldLabelText: 'Introduzir data',
        fieldHintText: 'dd/mm/aaaa',
        errorFormatText: 'Formato de data inválido',
        errorInvalidText: 'Data inválida',
        builder: (context, child) {
          return Theme(
            data: theme.copyWith(
              // Modern date picker styling
              colorScheme: colorScheme.copyWith(
                primary: colorScheme.primary,
                onPrimary: colorScheme.onPrimary,
                surface: colorScheme.surface,
                onSurface: colorScheme.onSurface,
                surfaceContainerHighest: colorScheme.surfaceContainerHighest,
                onSurfaceVariant: colorScheme.onSurfaceVariant,
              ),
              datePickerTheme: DatePickerThemeData(
                backgroundColor: colorScheme.surface,
                elevation: 4,
                shadowColor: colorScheme.shadow.withAlpha((255 * 0.1).round()),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                headerBackgroundColor: colorScheme.surface,
                headerForegroundColor: colorScheme.onSurface,
                headerHeadlineStyle: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                ),
                headerHelpStyle: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
                weekdayStyle: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                dayStyle: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w400,
                ),
                dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  if (states.contains(WidgetState.disabled)) {
                    return colorScheme.onSurface.withAlpha((255 * 0.3).round());
                  }
                  return colorScheme.onSurface;
                }),
                dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.primary.withAlpha((255 * 0.8).round());
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return colorScheme.primary.withAlpha((255 * 0.05).round());
                  }
                  return Colors.transparent;
                }),
                dayOverlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return colorScheme.primary.withAlpha((255 * 0.1).round());
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return colorScheme.primary.withAlpha((255 * 0.04).round());
                  }
                  return Colors.transparent;
                }),
                todayForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return colorScheme.primary.withAlpha((255 * 0.9).round());
                }),
                todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.primary.withAlpha((255 * 0.8).round());
                  }
                  return Colors.transparent;
                }),
                todayBorder: BorderSide(
                  color: colorScheme.primary.withAlpha((255 * 0.4).round()),
                  width: 1,
                ),
                yearStyle: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w400,
                ),
                yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return colorScheme.onSurface;
                }),
                yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return colorScheme.primary.withAlpha((255 * 0.8).round());
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return colorScheme.primary.withAlpha((255 * 0.05).round());
                  }
                  return Colors.transparent;
                }),
                yearOverlayColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.pressed)) {
                    return colorScheme.primary.withAlpha((255 * 0.1).round());
                  }
                  if (states.contains(WidgetState.hovered)) {
                    return colorScheme.primary.withAlpha((255 * 0.04).round());
                  }
                  return Colors.transparent;
                }),
                dividerColor: colorScheme.outline.withAlpha((255 * 0.08).round()),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha((255 * 0.3).round()),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.1).round())),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.1).round())),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.primary.withAlpha((255 * 0.6).round()), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary.withAlpha((255 * 0.9).round()),
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) onChanged(picked);
    }

    return SizedBox(
      height: 56,
      child: GestureDetector(
        onTap: pickDate,
        child: AbsorbPointer(
          child: TextFormField(
            controller: controller,
            readOnly: true,
            validator: validator != null ? (_) => validator!(value) : null,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: labelStyle ?? textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              hintText: hint ?? 'dd/mm/aaaa',
              hintStyle: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
              ),
              filled: true,
              fillColor: readOnly
                  ? colorScheme.surfaceContainerHighest.withAlpha((255 * 0.7).round())
                  : colorScheme.surfaceContainerHighest,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.2).round())),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.08).round())),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: Icon(
                Icons.calendar_today_rounded, 
                size: 20,
                color: readOnly 
                    ? colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round())
                    : colorScheme.onSurfaceVariant,
              ),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
          ),
        ),
      ),
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool readOnly;
  final String? Function(T?)? validator;
  final TextStyle? labelStyle;

  const AppDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.readOnly = false,
    this.validator,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return SizedBox(
      height: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<T>(
            value: value,
            items: items,
            onChanged: readOnly ? null : onChanged,
            validator: validator,
            isExpanded: true,
            selectedItemBuilder: (context) => items.map((item) {
              return Container(
                height: 24,
                alignment: Alignment.centerLeft,
                child: Text(
                  item.child is Text ? (item.child as Text).data ?? '' : item.value.toString(),
                  style: textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: labelStyle ?? textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              hintText: hint,
              hintStyle: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withAlpha((255 * 0.7).round()),
              ),
              filled: true,
              fillColor: readOnly
                  ? colorScheme.surfaceContainerHighest.withAlpha((255 * 0.7).round())
                  : colorScheme.surfaceContainerHighest,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.2).round())),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withAlpha((255 * 0.08).round())),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            style: textTheme.bodySmall,
            icon: const Icon(Icons.arrow_drop_down),
            dropdownColor: colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
} 