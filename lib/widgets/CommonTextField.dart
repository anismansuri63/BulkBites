import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utlity/AppColors.dart';

class CommonTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final void Function(String)? onChanged;
  final bool readOnly;
  final bool enabled;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  final VoidCallback? onTap;

  // Show clear/cancel button
  final bool showCancleButton;

  const CommonTextField({
    super.key,
    this.controller,
    required this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.enabled = true,
    this.onTap,
    this.showCancleButton = false,
    this.maxLength,
    this.inputFormatters,
  });

  @override
  State<CommonTextField> createState() => _CommonTextFieldState();
}

class _CommonTextFieldState extends State<CommonTextField> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();

    _hasText = widget.controller?.text.isNotEmpty ?? false;
    widget.controller?.addListener(_controllerListener);
  }

  void _controllerListener() {
    final hasText = widget.controller?.text.isNotEmpty ?? false;

    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_controllerListener);
    super.dispose();
  }

  void _clearText() {
    widget.controller?.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    Widget? suffix;

    if (widget.showCancleButton && _hasText) {
      suffix = IconButton(
        icon: const Icon(Icons.close),
        color: AppColors.textColor.withValues(alpha: 0.6),
        onPressed: _clearText,
      );
    } else {
      suffix = widget.suffixIcon;
    }

    return TextFormField(
      autocorrect: false,
      enableSuggestions: false,
      controller: widget.controller,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      inputFormatters: widget.inputFormatters,
      onChanged: (value) {
        widget.onChanged?.call(value);
      },
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      onTap: widget.onTap,
      style: const TextStyle(
        color: AppColors.textColor,
        fontSize: 15,
      ),
      cursorColor: AppColors.primary,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        counterText: "", // Hide the default counter
        labelStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: AppColors.textColor.withValues(alpha: 0.4),
          fontSize: 14,
        ),
        prefixIcon: widget.prefixIcon != null
            ? Icon(
          widget.prefixIcon,
          color: AppColors.primary,
          size: 22,
        )
            : null,
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.backgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.textColor.withValues(alpha: 0.1),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.textColor.withValues(alpha: 0.1),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2,
          ),
        ),
      ),
    );
  }
}