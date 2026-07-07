import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../utils/theme_helper.dart';

/// iOS-style back chevron used across chat screens.
///
/// Falls back to [Navigator.maybePop] when no [onPressed] is given.
class IosBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final double size;

  const IosBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.size = 26,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        CupertinoIcons.back,
        size: size,
        color: color ?? ThemeHelper.getTextPrimary(context),
      ),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}
