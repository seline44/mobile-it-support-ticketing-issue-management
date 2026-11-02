import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/td_theme.dart';
import 'td_widgets.dart';

bool tdIsActive(Ticket t) {
  return t.status == 'Open' ||
      t.status == 'In Progress' ||
      t.status == 'Pending';
}

DateTime tdLastTouched(Ticket t) {
  return t.lastModifiedAt ?? t.updatedAt ?? t.createdAt;
}

String tdTicketLabel(Ticket t) {
  return t.ticketNumber ?? 'ID ${t.id}';
}

String tdTimeAgo(DateTime dateTime) {
  final elapsed = DateTime.now().difference(dateTime.toLocal());
  if (elapsed.inDays > 0) return '${elapsed.inDays}d ago';
  if (elapsed.inHours > 0) return '${elapsed.inHours}h ago';
  if (elapsed.inMinutes > 0) return '${elapsed.inMinutes}m ago';
  return 'Just now';
}

class TdSignalBars {
  static int levelFor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
      default:
        return 1;
    }
  }

  static Widget build(String priority) {
    final level = levelFor(priority);
    final activeColor = level >= 3 ? TdColors.coral : TdColors.teal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 4; i++)
          Container(
            width: 3,
            height: 4.0 * i,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: i <= level ? activeColor : TdColors.line,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
      ],
    );
  }
}

class TdFilterChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelected;

  const TdFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final isSelected = selected == option;
          final count = counts[option] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text('$option ($count)'),
              onSelected: (_) => onSelected(option),
              selectedColor: theme.colorScheme.primaryContainer,
              checkmarkColor: theme.colorScheme.primary,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class TdTicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final bool isAccepting;

  const TdTicketCard({
    super.key,
    required this.ticket,
    required this.onTap,
    this.onAccept,
    this.isAccepting = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = _statusColors(ticket.status);
    final indicatorColor = _indicatorColor(ticket.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 42,
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tdTicketLabel(ticket),
                              style: TdFonts.monoStyle.copyWith(
                                fontSize: 12.5,
                                color: TdColors.teal,
                              ),
                            ),
                            TdPill(
                              label: ticket.status,
                              background: bg,
                              foreground: fg,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ticket.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ticket.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TdSignalBars.build(ticket.priority),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onAccept != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 12, bottom: 10),
                child: FilledButton.tonalIcon(
                  onPressed: isAccepting ? null : onAccept,
                  icon: isAccepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(isAccepting ? 'Accepting...' : 'Accept ticket'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  (Color, Color) _statusColors(String status) {
    switch (status) {
      case 'Open':
        return (TdColors.openBg, TdColors.openFg);
      case 'In Progress':
        return (TdColors.progressBg, TdColors.progressFg);
      case 'Resolved':
      case 'Closed':
        return (TdColors.resolvedBg, TdColors.resolvedFg);
      case 'Critical':
        return (TdColors.criticalBg, TdColors.criticalFg);
      default:
        return (TdColors.openBg, TdColors.openFg);
    }
  }

  Color _indicatorColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return TdColors.coral;
      case 'high':
        return TdColors.amber;
      case 'medium':
        return TdColors.teal;
      default:
        return TdColors.blue;
    }
  }
}
