import 'package:flutter/material.dart';

class InlineButtonProgress extends StatelessWidget {
  const InlineButtonProgress({
    super.key,
    required this.label,
    required this.inProgress,
    this.icon,
  });

  final String label;
  final bool inProgress;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final foreground =
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (inProgress || icon != null) ...[
          if (inProgress)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: foreground,
              ),
            ),
          if (!inProgress) icon!,
          const SizedBox(width: 9),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
