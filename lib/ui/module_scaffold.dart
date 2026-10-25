import 'package:flutter/material.dart';
import '../core/operational_panel.dart';
import 'tokens.dart';

class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold(
      {super.key,
      required this.title,
      this.subtitle,
      this.navigation,
      this.detail,
      required this.content,
      this.actions = const [],
      this.headerActions = const [],
      this.footerLabel,
      this.scrollContent = true});
  final String title;
  final String? subtitle, footerLabel;
  final Widget? navigation, detail;
  final Widget content;
  final List<Widget> actions, headerActions;
  final bool scrollContent;
  @override
  Widget build(BuildContext context) => ColoredBox(
      color: Colors.white,
      child: OperationalPanel(child: LayoutBuilder(builder: (context, size) {
        final narrow = size.maxWidth < 900;
        final mobile = MediaQuery.sizeOf(context).width < 760;
        Widget pane(Widget child, {bool border = false}) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: border
                    ? const Border(left: BorderSide(color: UiTokens.line))
                    : null),
            child: SingleChildScrollView(child: child));
        final body = narrow
            ? SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    if (navigation != null)
                      if (mobile)
                        ExpansionTile(
                          key: ValueKey('module-filters-$title'),
                          title: const Text('Filtros e grupos',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          tilePadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          children: [navigation!],
                        )
                      else
                        Container(
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(maxHeight: 190),
                            child: SingleChildScrollView(child: navigation!)),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: scrollContent
                            ? content
                            : SizedBox(
                                height: mobile && size.hasBoundedHeight
                                    ? (size.maxHeight * .65).clamp(220.0, 400.0)
                                    : 400,
                                child: content)),
                    if (detail != null) pane(detail!, border: true),
                  ]))
            : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (navigation != null)
                  SizedBox(
                      width: UiTokens.leftWidth,
                      child: Container(
                          decoration: const BoxDecoration(
                              border: Border(
                                  right: BorderSide(color: UiTokens.line))),
                          child: pane(navigation!))),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: scrollContent
                            ? SingleChildScrollView(child: content)
                            : content)),
                if (detail != null)
                  SizedBox(
                      width: UiTokens.rightWidth,
                      child: pane(detail!, border: true)),
              ]);
        final frame =
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: UiTokens.line))),
              child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: UiTokens.ink)),
                          if (subtitle != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(subtitle!,
                                    style: const TextStyle(
                                        fontSize: 11, color: UiTokens.muted)))
                        ]),
                    if (headerActions.isNotEmpty)
                      Wrap(spacing: 8, runSpacing: 6, children: headerActions),
                  ])),
          Expanded(child: body),
          if (actions.isNotEmpty || footerLabel != null)
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: UiTokens.line))),
                child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (footerLabel != null)
                        Text(footerLabel!,
                            style: const TextStyle(
                                fontSize: 10, color: UiTokens.muted)),
                      ...actions
                    ])),
        ]);
        return Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(UiTokens.radius),
                border: Border.all(color: UiTokens.line)),
            clipBehavior: Clip.antiAlias,
            child: size.hasBoundedHeight
                ? frame
                : SizedBox(height: 620, child: frame));
      })));
}

class ModuleSectionLabel extends StatelessWidget {
  const ModuleSectionLabel(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: .5,
              color: UiTokens.muted)));
}

class ModuleCard extends StatelessWidget {
  const ModuleCard({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: UiTokens.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: UiTokens.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        child
      ]));
}

class ModuleDetailRow extends StatelessWidget {
  const ModuleDetailRow(this.label, this.value, {super.key});
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 11, color: UiTokens.muted))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))
      ]));
}

class ModuleEmpty extends StatelessWidget {
  const ModuleEmpty(this.title, this.description,
      {super.key, this.icon = Icons.info_outline_rounded});
  final String title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 28, color: const Color(0xFF8194B1)),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        Text(description,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11, color: UiTokens.muted, height: 1.6))
      ]));
}

class ModuleListItem extends StatelessWidget {
  const ModuleListItem(
      {super.key,
      required this.title,
      this.subtitle,
      this.icon,
      this.trailing,
      this.selected = false,
      this.onTap});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .08)
              : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
              side: BorderSide(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : UiTokens.line,
                  width: selected ? 1.5 : 1)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Row(children: [
                    if (icon != null) ...[
                      Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                              color: UiTokens.surface,
                              borderRadius: BorderRadius.circular(8)),
                          child: Icon(icon,
                              size: 16, color: const Color(0xFF7A8CA8))),
                      const SizedBox(width: 9)
                    ],
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Theme.of(context).colorScheme.primary
                                      : UiTokens.ink)),
                          if (subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(subtitle!,
                                style: const TextStyle(
                                    fontSize: 10, color: UiTokens.muted))
                          ]
                        ])),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!
                    ],
                    if (selected)
                      Icon(Icons.chevron_right,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary)
                  ])))));
}

enum ModuleTone { success, critical, warning, info, neutral }

class ModuleStatusChip extends StatelessWidget {
  const ModuleStatusChip(this.label,
      {super.key, this.tone = ModuleTone.neutral});
  final String label;
  final ModuleTone tone;
  @override
  Widget build(BuildContext context) {
    final palette = switch (tone) {
      ModuleTone.success => (
          const Color(0xFFEAF7EE),
          const Color(0xFF1E7A3E),
          const Color(0xFFBFE5CB)
        ),
      ModuleTone.critical => (
          const Color(0xFFFDECEC),
          const Color(0xFFB42318),
          const Color(0xFFF5C2C2)
        ),
      ModuleTone.warning => (
          const Color(0xFFFEF3E6),
          const Color(0xFFA15C07),
          const Color(0xFFF8D4A8)
        ),
      ModuleTone.info => (
          const Color(0xFFEAF2FE),
          const Color(0xFF1557B8),
          const Color(0xFFC3D9FB)
        ),
      ModuleTone.neutral => (
          const Color(0xFFF3F5F8),
          const Color(0xFF3D4752),
          const Color(0xFFD5DBE3)
        )
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: palette.$1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: palette.$3)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: palette.$2)));
  }
}
