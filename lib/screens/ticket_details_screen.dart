import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/api_timestamp.dart';
import '../widgets/td_ticket_widgets.dart';

class TicketDetailsScreen extends StatefulWidget {
  final String id;
  final String title;
  final String description;
  final String category;
  final String impact;
  final String urgency;
  final String device;
  final String location;
  final String status;
  final String? resolution;
  final String? assignedTechnician;
  final String? reporterName;
  final String? reporterPhone;
  final DateTime? createdAt;
  final DateTime? lastModifiedAt;
  final DateTime? resolvedAt;

  const TicketDetailsScreen({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.impact,
    required this.urgency,
    required this.device,
    required this.location,
    required this.status,
    this.resolution,
    this.assignedTechnician,
    this.reporterName,
    this.reporterPhone,
    this.createdAt,
    this.lastModifiedAt,
    this.resolvedAt,
  });

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _CompleteTicketDialog extends StatefulWidget {
  const _CompleteTicketDialog();

  @override
  State<_CompleteTicketDialog> createState() => _CompleteTicketDialogState();
}

class _CompleteTicketDialogState extends State<_CompleteTicketDialog> {
  final _resolutionController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedStatus = 'Resolved';

  @override
  void dispose() {
    _resolutionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete ticket'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(labelText: 'New status'),
              items: const [
                DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                DropdownMenuItem(value: 'Closed', child: Text('Closed')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _selectedStatus = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _resolutionController,
              minLines: 2,
              maxLines: 4,
              maxLength: 10000,
              decoration: const InputDecoration(
                labelText: 'Resolution',
                hintText: 'Describe how the issue was fixed',
                alignLabelWithHint: true,
              ),
            ),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Internal work note (optional)',
                hintText: 'Only visible to technicians and administrators',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final resolution = _resolutionController.text.trim();
            if (resolution.isEmpty) return;
            Navigator.pop(context, {
              'status': _selectedStatus,
              'resolution': resolution,
              'note': _noteController.text.trim(),
            });
          },
          child: const Text('Save update'),
        ),
      ],
    );
  }
}

class _ReopenTicketDialog extends StatefulWidget {
  const _ReopenTicketDialog();

  @override
  State<_ReopenTicketDialog> createState() => _ReopenTicketDialogState();
}

class _ReopenTicketDialogState extends State<_ReopenTicketDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canReopen = _reasonController.text.trim().length >= 3;
    return AlertDialog(
      title: const Text('Reopen ticket'),
      content: TextField(
        controller: _reasonController,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 2000,
        decoration: const InputDecoration(
          labelText: 'Why are you unsatisfied?',
          hintText: 'Explain what still needs attention',
          alignLabelWithHint: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canReopen
              ? () => Navigator.pop(context, _reasonController.text.trim())
              : null,
          child: const Text('Reopen ticket'),
        ),
      ],
    );
  }
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _updates = [];
  bool _isLoadingHistory = true;
  String? _historyError;
  late String _status;
  String? _resolution;
  bool _isSavingStatus = false;
  bool _commentIsInternal = false;
  bool _historyLoadInProgress = false;
  late String _title;
  late String _description;
  String? _assignedTechnician;
  DateTime? _lastModifiedAt;
  DateTime? _resolvedAt;
  Timer? _liveUpdateTimer;

  @override
  void initState() {
    super.initState();
    _status = widget.status;
    _resolution = widget.resolution;
    _title = widget.title;
    _description = widget.description;
    _assignedTechnician = widget.assignedTechnician;
    _lastModifiedAt = widget.lastModifiedAt;
    _resolvedAt = widget.resolvedAt;
    _loadHistory();
    _liveUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _loadHistory();
      }
    });
  }

  @override
  void dispose() {
    _liveUpdateTimer?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  static const Color blue = AppTheme.accentTeal;
  static const Color success = AppTheme.accentTeal;
  static const Color warning = AppTheme.warningGold;
  static const Color danger = Color(0xFFDC2626);

  Color _statusColor() {
    switch (_status.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return success;
      case 'in progress':
        return blue;
      case 'open':
      default:
        return warning;
    }
  }

  Color _priorityColor() {
    if (widget.impact.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'critical') {
      return danger;
    }
    if (widget.urgency.toLowerCase() == 'high' ||
        widget.impact.toLowerCase() == 'high') {
      return warning;
    }
    return blue;
  }

  String _calculatedPriority() {
    if (widget.impact.toLowerCase() == 'critical' ||
        widget.urgency.toLowerCase() == 'critical') {
      return 'Critical';
    }
    if (widget.impact.toLowerCase() == 'high' ||
        widget.urgency.toLowerCase() == 'high') {
      return 'High';
    }
    if (widget.impact.toLowerCase() == 'medium' ||
        widget.urgency.toLowerCase() == 'medium') {
      return 'Medium';
    }
    return 'Low';
  }

  IconData _categoryIcon() {
    switch (widget.category.toLowerCase()) {
      case 'hardware':
        return Icons.devices_outlined;
      case 'software':
        return Icons.apps_outlined;
      case 'network':
        return Icons.wifi_rounded;
      case 'email':
        return Icons.email_outlined;
      case 'account access':
        return Icons.lock_outline_rounded;
      case 'printer':
      case 'printing':
        return Icons.print_outlined;
      default:
        return Icons.laptop_mac_outlined;
    }
  }

  Future<void> _loadHistory() async {
    if (_historyLoadInProgress) return;
    _historyLoadInProgress = true;
    final ticketId = int.tryParse(widget.id);
    if (ticketId == null) {
      setState(() {
        _historyError = 'Ticket activity is unavailable for this ticket ID.';
        _isLoadingHistory = false;
      });
      _historyLoadInProgress = false;
      return;
    }

    try {
      final results = await Future.wait<dynamic>([
        ApiService.getTicket(ticketId),
        ApiService.getTicketHistory(ticketId),
        ApiService.getTicketNotes(ticketId),
      ]);
      final ticket = results[0] as Map<String, dynamic>;
      final history = results[1];
      final notes = results[2];
      if (!mounted) return;
      final updates = <Map<String, dynamic>>[];
      for (final item in history.whereType<Map>()) {
        final entry = Map<String, dynamic>.from(item);
        final actor = entry['actor_name']?.toString();
        final action = entry['action']?.toString() ?? 'Ticket updated';
        final details = entry['details']?.toString();
        final createdAt = parseApiTimestamp(entry['created_at'].toString());
        final title = [
          if (actor != null && actor.isNotEmpty) '$actor: ',
          action,
          if (details != null && details.isNotEmpty) ' - $details',
        ].join();
        updates.add({
          'title': title,
          'time': _formatHistoryTime(createdAt),
          'sortTime': createdAt,
        });
      }
      for (final item in notes.whereType<Map>()) {
        final entry = Map<String, dynamic>.from(item);
        final author = entry['author_name']?.toString();
        final isInternal = entry['is_internal'] == true;
        final createdAt = parseApiTimestamp(entry['created_at'].toString());
        updates.add({
          'title':
              '${isInternal ? '🔒 Internal note · ' : ''}'
              '${author == null || author.isEmpty ? 'User' : author}: '
              '${entry['note']}',
          'time': _formatHistoryTime(createdAt),
          'sortTime': createdAt,
        });
      }
      updates.sort(
        (a, b) =>
            (a['sortTime'] as DateTime).compareTo(b['sortTime'] as DateTime),
      );
      setState(() {
        _title = ticket['title']?.toString() ?? _title;
        _description = ticket['description']?.toString() ?? _description;
        _status = ticket['status']?.toString() ?? _status;
        _resolution = ticket['resolution']?.toString();
        _assignedTechnician = ticket['assigned_technician_name']?.toString();
        _lastModifiedAt = ticket['last_modified_at'] == null
            ? null
            : parseApiTimestamp(ticket['last_modified_at'].toString());
        _resolvedAt = ticket['resolved_at'] == null
            ? null
            : parseApiTimestamp(ticket['resolved_at'].toString());
        _updates
          ..clear()
          ..addAll(updates);
        _historyError = null;
        _isLoadingHistory = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyError = error.toString().replaceFirst('Exception: ', '');
        _isLoadingHistory = false;
      });
    } finally {
      _historyLoadInProgress = false;
    }
  }

  Future<void> _changeStatus() async {
    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (_) => const _CompleteTicketDialog(),
      );

      if (result == null) return;
      final ticketId = int.tryParse(widget.id);
      if (ticketId == null) {
        throw Exception('Could not identify this ticket.');
      }

      setState(() => _isSavingStatus = true);
      final updated = await ApiService.updateTicketStatus(
        ticketId: ticketId,
        status: result['status']!,
        resolution: result['resolution'],
        note: result['note']!.isEmpty ? null : result['note'],
      );
      if (!mounted) return;
      setState(() {
        _status = updated['status']?.toString() ?? result['status']!;
        _resolution = updated['resolution']?.toString() ?? result['resolution'];
      });
      await _loadHistory();
      if (!mounted) return;
      final emailSent = updated['email_notification_sent'] == true;
      final emailFailed = updated['email_notification_sent'] == false;
      final isResolved = {'Resolved', 'Closed'}.contains(_status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isResolved
                ? 'Ticket $_status successfully.'
                : emailSent
                ? 'Ticket $_status. Email accepted by the mail server and update added to TriageDesk notifications.'
                : emailFailed
                ? 'Ticket $_status and update added to TriageDesk notifications, but the reporter email could not be sent. Check backend logs.'
                : 'Ticket $_status successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted && _isSavingStatus) {
        setState(() => _isSavingStatus = false);
      }
    }
  }

  Future<void> _reopenTicket() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReopenTicketDialog(),
    );
    if (!mounted || reason == null) return;

    final ticketId = int.tryParse(widget.id);
    if (ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this ticket.')),
      );
      return;
    }

    setState(() => _isSavingStatus = true);
    try {
      final result = await ApiService.reopenTicket(
        ticketId: ticketId,
        reason: reason,
      );
      if (!mounted) return;
      setState(() {
        _status = result['status']?.toString() ?? 'Open';
        _resolution = result['resolution']?.toString() ?? _resolution;
      });
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket reopened successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingStatus = false);
    }
  }

  String _formatHistoryTime(DateTime createdAt) {
    final date = createdAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final time = TimeOfDay.fromDateTime(date).format(context);
    if (dateOnly == today) return 'Today, $time';
    if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return '${date.month}/${date.day}/${date.year}, $time';
  }

  Future<void> _addComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) return;

    final ticketId = int.tryParse(widget.id);
    if (ticketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not identify this ticket.')),
      );
      return;
    }
    try {
      final isStaff = ApiService.currentUser?['role'] != 'Reporter';
      final result = await ApiService.addTicketNote(
        ticketId: ticketId,
        note: comment,
        isInternal: isStaff ? _commentIsInternal : false,
      );
      if (!mounted) return;
      _commentController.clear();
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isStaff &&
                    !_commentIsInternal &&
                    result['whatsapp_notification_sent'] == false
                ? 'Reply saved, but WhatsApp could not send it. Check the reporter’s linked number and backend delivery logs.'
                : 'Comment added successfully',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not add comment: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textPrimary = theme.colorScheme.onSurface;
    final textSecondary = theme.colorScheme.onSurfaceVariant;
    final cardColor = theme.cardColor;
    final borderColor = theme.colorScheme.outlineVariant;

    final statusColor = _statusColor();
    final priority = _calculatedPriority();
    final priorityColor = _priorityColor();
    final isTechnician = ApiService.currentUser?['role'] == 'Technician';
    final isReporter = ApiService.currentUser?['role'] == 'Reporter';
    final isStaff =
        isTechnician || ApiService.currentUser?['role'] == 'Administrator';
    final canViewRequester =
        isTechnician || ApiService.currentUser?['role'] == 'Administrator';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ticket Details',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: blue.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_categoryIcon(), color: blue, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.id.startsWith('#')
                                  ? widget.id
                                  : '#${widget.id}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _status,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                                if (_lastModifiedAt != null)
                                  Text(
                                    _formatHistoryTime(_lastModifiedAt!),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (isTechnician && _status == 'In Progress') ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSavingStatus ? null : _changeStatus,
                        icon: _isSavingStatus
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.task_alt_rounded),
                        label: const Text('Resolve or close ticket'),
                      ),
                    ),
                  ],
                  if (isReporter &&
                      {'Resolved', 'Closed'}.contains(_status)) ...[
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSavingStatus ? null : _reopenTicket,
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Reopen ticket'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'If the issue is not fixed, tell us what still needs attention.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _CsatRatingCard(ticketId: widget.id),
                  ],

                  const SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: SelectableText(
                      _description,
                      style: TextStyle(color: textPrimary, height: 1.5),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Metadata Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        _metaRow(
                          'Category',
                          widget.category,
                          textPrimary,
                          textSecondary,
                        ),
                        const Divider(height: 20),
                        _metaRow(
                          'Priority',
                          priority,
                          priorityColor,
                          textSecondary,
                          isBold: true,
                        ),
                        const Divider(height: 20),
                        _metaRow(
                          'Created',
                          widget.createdAt == null
                              ? 'Date unavailable'
                              : tdFormatDateTime(context, widget.createdAt!),
                          textPrimary,
                          textSecondary,
                        ),
                        if (_resolvedAt != null) ...[
                          const Divider(height: 20),
                          _metaRow(
                            'Resolved',
                            tdFormatDateTime(context, _resolvedAt!),
                            textPrimary,
                            textSecondary,
                          ),
                        ],
                        const Divider(height: 20),
                        _metaRow(
                          'Assigned to',
                          _assignedTechnician ?? 'Unassigned',
                          textPrimary,
                          textSecondary,
                        ),
                        if (canViewRequester &&
                            (widget.reporterName?.isNotEmpty == true ||
                                widget.reporterPhone?.isNotEmpty == true)) ...[
                          const Divider(height: 20),
                          _metaRow(
                            'Requested by',
                            widget.reporterName ?? 'WhatsApp requester',
                            textPrimary,
                            textSecondary,
                          ),
                          if (widget.reporterPhone?.isNotEmpty == true) ...[
                            const Divider(height: 20),
                            _metaRow(
                              'WhatsApp',
                              widget.reporterPhone!,
                              textPrimary,
                              textSecondary,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  if (_resolution != null && _resolution!.isNotEmpty) ...[
                    Text(
                      'Resolution',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(_resolution!),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Updates Timeline Section
                  Text(
                    'Updates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isLoadingHistory)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_historyError != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  _historyError!,
                                  style: TextStyle(color: textSecondary),
                                ),
                                TextButton(
                                  onPressed: _loadHistory,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          )
                        else if (_updates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'No activity recorded yet.',
                              style: TextStyle(color: textSecondary),
                            ),
                          )
                        else
                          for (int i = 0; i < _updates.length; i++)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: blue.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: blue,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: blue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (i < _updates.length - 1)
                                      Container(
                                        width: 2,
                                        height: 38,
                                        color: blue.withValues(alpha: 0.3),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _updates[i]['title']!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          _updates[i]['time']!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Comment & Send Bar
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isStaff)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: DropdownButton<bool>(
                      value: _commentIsInternal,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('Internal note · staff only'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('Public reply · reporter can see'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _commentIsInternal = value);
                        }
                      },
                    ),
                  ),
                if (isStaff) const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: isStaff && _commentIsInternal
                              ? 'Add an internal note (staff only)...'
                              : isStaff
                              ? 'Write a reply to the reporter...'
                              : 'Send an update to the support team...',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: blue, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Material(
                      color: blue,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _addComment,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(
    String label,
    String value,
    Color valueColor,
    Color textSecondary, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _CsatRatingCard extends StatefulWidget {
  final String ticketId;
  const _CsatRatingCard({required this.ticketId});

  @override
  State<_CsatRatingCard> createState() => _CsatRatingCardState();
}

class _CsatRatingCardState extends State<_CsatRatingCard> {
  int _selectedRating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _submitted = false;
  bool _submitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitCsat() async {
    if (_selectedRating == 0) return;
    setState(() => _submitting = true);
    try {
      final ticketId = int.tryParse(widget.ticketId);
      if (ticketId != null) {
        final comment = _feedbackController.text.trim();
        final note =
            'CSAT Rating: $_selectedRating/5${comment.isNotEmpty ? ' - $comment' : ''}';
        await ApiService.addTicketNote(ticketId: ticketId, note: note);
      }
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _submitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not submit rating: ${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_submitted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F3EA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF1E7A50).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF1E7A50)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rating submitted successfully',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E7A50),
                    ),
                  ),
                  Text(
                    'You rated this support experience $_selectedRating/5 star${_selectedRating == 1 ? '' : 's'}.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1E7A50),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How was your support experience?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Rate the resolution quality to help our IT team improve.',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _selectedRating = i),
                  icon: Icon(
                    i <= _selectedRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i <= _selectedRating
                        ? const Color(0xFFE8A13A)
                        : theme.colorScheme.onSurfaceVariant,
                    size: 32,
                  ),
                ),
            ],
          ),
          if (_selectedRating > 0) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _feedbackController,
              decoration: const InputDecoration(
                hintText: 'Add an optional comment...',
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submitCsat,
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit rating'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
