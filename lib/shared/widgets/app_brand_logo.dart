import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Logotipo oficial do Finance Control utilizado nas telas de autenticação e identificação da marca.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = 48,
    this.borderRadius,
  });

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.24);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Icon(
            Icons.account_balance_rounded,
            color: Colors.white,
            size: size * 0.54,
          ),
        ),
      ),
    );
  }
}
