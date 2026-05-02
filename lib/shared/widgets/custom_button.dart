import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// Enum for button types
enum ButtonType { primary, secondary, outlined, text, gradient }

/// Enum for button sizes
enum ButtonSize { small, medium, large }

/// Custom Button Widget - Modular and reusable button component
/// Compatible with Riverpod 3.0
class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final Widget? customChild;

  final double? customFontSize;
  final double? customIconSize;
  final EdgeInsetsGeometry? customPadding;

  const CustomButton({
    required this.label,
    super.key,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.width,
    this.height,
    this.borderRadius,
    this.padding,
    this.textStyle,
    this.customChild,
    this.customFontSize,
    this.customIconSize,
    this.customPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isButtonDisabled = isDisabled || isLoading || onPressed == null;

    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? _getHeightForSize(),
      child: _buildButton(isButtonDisabled),
    );
  }

  double _getHeightForSize() {
    switch (size) {
      case ButtonSize.small:
        return 40.h;
      case ButtonSize.medium:
        return 50.h;
      case ButtonSize.large:
        return 60.h;
    }
  }

  double _getFontSizeForSize() {
    if (customFontSize != null) return customFontSize!;

    switch (size) {
      case ButtonSize.small:
        return 13.sp;
      case ButtonSize.medium:
        return 15.sp;
      case ButtonSize.large:
        return 17.sp;
    }
  }

  double _getIconSizeForSize() {
    if (customIconSize != null) return customIconSize!;

    switch (size) {
      case ButtonSize.small:
        return 18.sp;
      case ButtonSize.medium:
        return 20.sp;
      case ButtonSize.large:
        return 24.sp;
    }
  }

  Widget _buildButton(bool isButtonDisabled) {
    switch (type) {
      case ButtonType.primary:
        return _buildPrimaryButton(isButtonDisabled);
      case ButtonType.secondary:
        return _buildSecondaryButton(isButtonDisabled);
      case ButtonType.outlined:
        return _buildOutlinedButton(isButtonDisabled);
      case ButtonType.text:
        return _buildTextButton(isButtonDisabled);
      case ButtonType.gradient:
        return _buildGradientButton(isButtonDisabled);
    }
  }

  Widget _buildPrimaryButton(bool isButtonDisabled) {
    return ElevatedButton(
      onPressed: isButtonDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.secondary,
        disabledBackgroundColor: AppColors.neutral.withValues(alpha: 0.3),
        foregroundColor: textColor ?? Colors.white,
        padding:
            customPadding ??
            padding ??
            EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12.r),
        ),
        elevation: isButtonDisabled ? 0 : 2,
        shadowColor: AppColors.shadow,
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildSecondaryButton(bool isButtonDisabled) {
    return ElevatedButton(
      onPressed: isButtonDisabled ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? AppColors.primary,
        disabledBackgroundColor: AppColors.neutral.withValues(alpha: 0.3),
        foregroundColor: textColor ?? Colors.white,
        padding:
            customPadding ??
            padding ??
            EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12.r),
        ),
        elevation: isButtonDisabled ? 0 : 2,
        shadowColor: AppColors.shadow,
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildOutlinedButton(bool isButtonDisabled) {
    return OutlinedButton(
      onPressed: isButtonDisabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: textColor ?? AppColors.secondary,
        disabledForegroundColor: AppColors.textDisabled,
        padding:
            customPadding ??
            padding ??
            EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        side: BorderSide(
          color: isButtonDisabled
              ? AppColors.border
              : (borderColor ?? AppColors.secondary),
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12.r),
        ),
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildTextButton(bool isButtonDisabled) {
    return TextButton(
      onPressed: isButtonDisabled ? null : onPressed,
      style: TextButton.styleFrom(
        foregroundColor: textColor ?? AppColors.secondary,
        disabledForegroundColor: AppColors.textDisabled,
        padding:
            customPadding ??
            padding ??
            EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius ?? 12.r),
        ),
      ),
      child: _buildButtonContent(),
    );
  }

  Widget _buildGradientButton(bool isButtonDisabled) {
    return Container(
      decoration: BoxDecoration(
        gradient: isButtonDisabled
            ? null
            : const LinearGradient(
                colors: [AppColors.secondary, AppColors.primary],
              ),
        color: isButtonDisabled
            ? AppColors.neutral.withValues(alpha: 0.3)
            : null,
        borderRadius: BorderRadius.circular(borderRadius ?? 12.r),
        boxShadow: isButtonDisabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isButtonDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius ?? 12.r),
          child: Container(
            padding:
                customPadding ??
                padding ??
                EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            child: _buildButtonContent(forceWhiteColor: true),
          ),
        ),
      ),
    );
  }

  Widget _buildButtonContent({bool forceWhiteColor = false}) {
    if (customChild != null) return customChild!;

    if (isLoading) {
      return SizedBox(
        height: 24.h,
        width: 24.w,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            forceWhiteColor
                ? Colors.white
                : (textColor ??
                      (type == ButtonType.outlined || type == ButtonType.text
                          ? AppColors.secondary
                          : Colors.white)),
          ),
        ),
      );
    }

    final children = <Widget>[];

    if (leadingIcon != null) {
      children
        ..add(
          Icon(
            leadingIcon,
            size: _getIconSizeForSize(),
            color: forceWhiteColor
                ? Colors.white
                : (textColor ??
                      (type == ButtonType.outlined || type == ButtonType.text
                          ? AppColors.secondary
                          : Colors.white)),
          ),
        )
        ..add(SizedBox(width: 8.w));
    }

    children.add(
      Flexible(
        child: Text(
          label,
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style:
              textStyle ??
              TextStyle(
                fontSize: _getFontSizeForSize(),
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
                color: forceWhiteColor
                    ? Colors.white
                    : (textColor ??
                          (type == ButtonType.outlined ||
                                  type == ButtonType.text
                              ? AppColors.secondary
                              : Colors.white)),
              ),
        ),
      ),
    );

    if (trailingIcon != null) {
      children
        ..add(SizedBox(width: 8.w))
        ..add(
          Icon(
            trailingIcon,
            size: _getIconSizeForSize(),
            color: forceWhiteColor
                ? Colors.white
                : (textColor ??
                      (type == ButtonType.outlined || type == ButtonType.text
                          ? AppColors.secondary
                          : Colors.white)),
          ),
        );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// Primary Button - Blue filled button
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final ButtonSize size;
  final double? width;
  final double? height;
  final double? customFontSize;
  final double? customIconSize;
  final EdgeInsetsGeometry? customPadding;

  const PrimaryButton({
    required this.label,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.size = ButtonSize.medium,
    this.width,
    this.height,
    this.customFontSize,
    this.customIconSize,
    this.customPadding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      isDisabled: isDisabled,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      size: size,
      width: width,
      height: height,
      customFontSize: customFontSize,
      customIconSize: customIconSize,
      customPadding: customPadding,
    );
  }
}

/// Secondary Button - Dark blue filled button
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final ButtonSize size;
  final double? width;
  final double? height;
  final double? customFontSize;
  final double? customIconSize;
  final EdgeInsetsGeometry? customPadding;

  const SecondaryButton({
    required this.label,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.size = ButtonSize.medium,
    this.width,
    this.height,
    this.customFontSize,
    this.customIconSize,
    this.customPadding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      label: label,
      onPressed: onPressed,
      type: ButtonType.secondary,
      isLoading: isLoading,
      isDisabled: isDisabled,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      size: size,
      width: width,
      height: height,
      customFontSize: customFontSize,
      customIconSize: customIconSize,
      customPadding: customPadding,
    );
  }
}

/// Outlined Button - Border only
class OutlinedCustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final ButtonSize size;
  final double? width;
  final double? height;
  final double? customFontSize;
  final double? customIconSize;
  final EdgeInsetsGeometry? customPadding;

  const OutlinedCustomButton({
    required this.label,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.size = ButtonSize.medium,
    this.width,
    this.height,
    this.customFontSize,
    this.customIconSize,
    this.customPadding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      label: label,
      onPressed: onPressed,
      type: ButtonType.outlined,
      isLoading: isLoading,
      isDisabled: isDisabled,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      size: size,
      width: width,
      height: height,
      customFontSize: customFontSize,
      customIconSize: customIconSize,
      customPadding: customPadding,
    );
  }
}

/// Gradient Button - Gradient background
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final ButtonSize size;
  final double? width;
  final double? height;
  final double? customFontSize;
  final double? customIconSize;
  final EdgeInsetsGeometry? customPadding;

  const GradientButton({
    required this.label,
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.leadingIcon,
    this.trailingIcon,
    this.size = ButtonSize.medium,
    this.width,
    this.height,
    this.customFontSize,
    this.customIconSize,
    this.customPadding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      label: label,
      onPressed: onPressed,
      type: ButtonType.gradient,
      isLoading: isLoading,
      isDisabled: isDisabled,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      size: size,
      width: width,
      height: height,
      customFontSize: customFontSize,
      customIconSize: customIconSize,
      customPadding: customPadding,
    );
  }
}

/// Pill-shaped, intrinsic-width primary action button — used as a
/// floating-style "+ Add" button anchored at the bottom of list screens
/// (parties list, products list, customers list, etc.). Mirrors the
/// styling of the Add Party FAB so the affordance is consistent across
/// the app.
class PrimaryFabButton extends StatelessWidget {
  const PrimaryFabButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(18.r),
      elevation: 4,
      shadowColor: AppColors.shadow,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: AppColors.textWhite, size: 22.sp),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textWhite,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
