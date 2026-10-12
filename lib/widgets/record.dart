import 'dart:ui' show FontFeature;

import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:flutter/material.dart';

import 'chip.dart';

class RecordTextStyles {
  final TextStyle? primary;
  final TextStyle? secondary;
  final TextStyle? muted;

  const RecordTextStyles._({this.primary, this.secondary, this.muted});

  factory RecordTextStyles.of(BuildContext context) {
    final colorScheme = context.colorScheme;
    final textTheme = context.textTheme;
    final secondary = textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    return RecordTextStyles._(
      primary: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
      secondary: secondary,
      muted: secondary?.copyWith(color: colorScheme.outline),
    );
  }
}

class RecordHeader extends StatelessWidget {
  final List<Widget> children;
  final Widget? trailing;

  const RecordHeader({super.key, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    return DefaultTextStyle.merge(
      style: context.textTheme.labelMedium?.copyWith(
        color: context.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w400,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: children,
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}

class RecordLabel extends StatelessWidget {
  final String label;
  final RecordTone tone;
  final VoidCallback? onPressed;

  const RecordLabel({
    super.key,
    required this.label,
    this.tone = RecordTone.neutral,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final capsule = CommonInfoCapsule(
      label,
      color: tone.labelColor(context),
      backgroundColor: tone.labelContainerColor(context),
    );
    if (onPressed != null) {
      return InkWell(
        onTap: onPressed,
        customBorder: const SuperellipseBorder(
          borderRadius: BorderRadius.all(Radius.circular(1000)),
        ),
        child: capsule,
      );
    }
    return capsule;
  }
}

class RecordTimestamp extends StatelessWidget {
  final String dateTime;

  const RecordTimestamp(this.dateTime, {super.key});

  @override
  Widget build(BuildContext context) {
    final split = dateTime.lastIndexOf(' ');
    return Text.rich(
      TextSpan(
        children: [
          if (split > 0)
            TextSpan(
              text: dateTime.substring(0, split + 1),
              style: TextStyle(color: context.colorScheme.outline),
            ),
          TextSpan(text: split > 0 ? dateTime.substring(split + 1) : dateTime),
        ],
      ),
      maxLines: 1,
    );
  }
}

class RecordArrow extends StatelessWidget {
  const RecordArrow({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      '→',
      style: RecordTextStyles.of(context).muted?.toJetBrainsMono,
    );
  }
}
