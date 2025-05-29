import 'package:flutter/material.dart';

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
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    InputDecoration _inputDecoration() {
      return InputDecoration(
        labelText: label,
        labelStyle: labelStyle ?? textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        hintText: hint,
        hintStyle: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
        filled: true,
        fillColor: readOnly
            ? colorScheme.surfaceVariant.withOpacity(0.7)
            : colorScheme.surfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.08)),
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
        decoration: _inputDecoration().copyWith(
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
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.readOnly = false,
    this.validator,
    this.firstDate,
    this.lastDate,
    this.labelStyle,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final controller = TextEditingController(
      text: value != null ?
        MaterialLocalizations.of(context).formatFullDate(value!) : '',
    );

    Future<void> _pickDate() async {
      if (readOnly) return;
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime(1990, 1, 1),
        firstDate: firstDate ?? DateTime(1900),
        lastDate: lastDate ?? DateTime.now(),
      );
      if (picked != null) onChanged(picked);
    }

    return SizedBox(
      height: 56,
      child: GestureDetector(
        onTap: _pickDate,
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
              hintText: (controller.text.isEmpty) ? '' : hint,
              hintStyle: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              filled: true,
              fillColor: colorScheme.surfaceVariant,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.08)),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: const Icon(Icons.calendar_today, size: 20),
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
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.readOnly = false,
    this.validator,
    this.labelStyle,
    Key? key,
  }) : super(key: key);

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
                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
              filled: true,
              fillColor: readOnly
                  ? colorScheme.surfaceVariant.withOpacity(0.7)
                  : colorScheme.surfaceVariant,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colorScheme.outline.withOpacity(0.08)),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            style: textTheme.bodySmall,
            icon: const Icon(Icons.arrow_drop_down),
            dropdownColor: colorScheme.surfaceVariant,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
} 