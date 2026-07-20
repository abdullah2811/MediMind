// TODO Implement this library.
import 'package:flutter/material.dart';

import 'app_localization.dart';

/// A small button that flips the app between English and Bangla.
class LanguageToggleButton extends StatelessWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppLocalizationScope.of(context);
    return ValueListenableBuilder<AppLocale>(
      valueListenable: controller,
      builder: (context, locale, _) {
        return IconButton(
          tooltip: 'Change language',
          icon: const Icon(Icons.translate),
          onPressed: controller.toggle,
        );
      },
    );
  }
}