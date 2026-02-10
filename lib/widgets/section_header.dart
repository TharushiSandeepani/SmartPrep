import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.iconBackgroundColor,
    this.titleStyle,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Color? iconBackgroundColor;
  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    final Color accent = iconBackgroundColor ?? const Color(0xFF1EA77B);
    final TextStyle headerStyle =
        titleStyle ??
        const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'SummaryNotes',
          color: Color(0xFF1EA77B),
        );

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: accent.withOpacity(0.12),
          child: Icon(icon, color: accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: headerStyle)),
        if (trailing != null) trailing!,
      ],
    );
  }
}
