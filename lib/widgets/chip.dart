import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:flutter/material.dart';

import 'text.dart';

/// Inline capsule for card subtitles (expiry date, 本地文件…), matching FlClash's
/// ExpireChip: a 15% theme tint, h8/v2 padding and a full superellipse.
class CommonInfoCapsule extends StatelessWidget {
  final String label;
  final TextStyle? style;

  const CommonInfoCapsule(this.label, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final color = colorScheme.primary;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.15),
        shape: SuperellipseBorder(borderRadius: BorderRadius.circular(1000)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: EmojiText(
          label,
          style: (style ?? context.textTheme.labelMedium)?.copyWith(
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class CommonChip extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ChipType type;
  final Widget? avatar;
  final TextStyle? labelStyle;

  const CommonChip({
    super.key,
    required this.label,
    this.labelStyle,
    this.onPressed,
    this.avatar,
    this.type = ChipType.action,
  });

  @override
  Widget build(BuildContext context) {
    final focusedBorder = WidgetStateBorderSide.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return BorderSide(
          color: context.colorScheme.primary,
          width: 2,
        );
      }
      return null;
    });
    final focusedColor = WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) {
        return context.colorScheme.primary.withValues(alpha: 0.2);
      }
      return null;
    });

    if (type == ChipType.delete) {
      return Chip(
        avatar: avatar,
        side: focusedBorder,
        color: focusedColor,
        labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
        clipBehavior: Clip.antiAlias,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onDeleted: onPressed ?? () {},
        labelStyle: labelStyle,
        label: EmojiText(label),
      );
    }
    return ActionChip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      avatar: avatar,
      side: focusedBorder,
      color: focusedColor,
      clipBehavior: Clip.antiAlias,
      labelPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4),
      onPressed: onPressed ?? () {},
      labelStyle: labelStyle,
      label: EmojiText(label),
    );
  }
}
