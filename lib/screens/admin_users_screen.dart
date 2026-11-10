import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/td_theme.dart';
import '../widgets/td_ticket_widgets.dart';
import '../widgets/td_widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'All';
  final Set<int> _updatingUserIds = {};
  final Set<int> _deletingUserIds = {};
  static const _filters = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final users = await ApiService.getAllUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _approvalStatus(Map<String, dynamic> user) {
    final status = (user['approval_status'] ?? 'Pending').toString().trim();
    if (status.toLowerCase() == 'approved') return 'Approved';
    if (status.toLowerCase() == 'rejected') return 'Rejected';
    if (status.toLowerCase() == 'pending') return 'Pending';
    return status.isEmpty ? 'Pending' : status;
  }

  int _countFor(String status) {
    if (status == 'All') return _users.length;
    return _users.where((item) {
      if (item is! Map) return false;
      return _approvalStatus(Map<String, dynamic>.from(item)).toLowerCase() ==
          status.toLowerCase();
    }).length;
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final result = <Map<String, dynamic>>[];
    for (final item in _users) {
      if (item is! Map) continue;
      final user = Map<String, dynamic>.from(item);
      if (_selectedFilter == 'All' ||
          _approvalStatus(user).toLowerCase() ==
              _selectedFilter.toLowerCase()) {
        result.add(user);
      }
    }
    result.sort((a, b) {
      final pendingA = _approvalStatus(a) == 'Pending' ? 0 : 1;
      final pendingB = _approvalStatus(b) == 'Pending' ? 0 : 1;
      if (pendingA != pendingB) return pendingA.compareTo(pendingB);

      final nameA =
          (a['full_name'] ?? a['email'] ?? '').toString().toLowerCase();
      final nameB =
          (b['full_name'] ?? b['email'] ?? '').toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
    return result;
  }

  int? _userId(Map<String, dynamic> user) {
    final rawId = user['id'] ?? user['user_id'];
    return rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
  }

  Future<void> _updateApproval(Map<String, dynamic> user, String status) async {
    final userId = _userId(user);
    if (userId == null) {
      _showMessage('Could not identify this account.');
      return;
    }
    setState(() => _updatingUserIds.add(userId));
    try {
      await ApiService.updateUserApproval(
        userId: userId,
        approvalStatus: status,
      );
      if (!mounted) return;
      setState(() {
        for (final item in _users) {
          if (item is! Map) continue;
          final itemId = item['id'] ?? item['user_id'];
          if (itemId.toString() == userId.toString()) {
            item['approval_status'] = status;
            break;
          }
        }
        _updatingUserIds.remove(userId);
      });
      _showMessage(
        status == 'Approved'
            ? 'Account approved successfully.'
            : 'Account rejected successfully.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(userId));
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _linkWhatsAppNumber(Map<String, dynamic> user) async {
    final userId = _userId(user);
    if (userId == null) {
      _showMessage('Could not identify this account.');
      return;
    }
    final phoneNumber = await showDialog<String>(
      context: context,
      builder: (_) => const _WhatsAppNumberDialog(),
    );
    if (phoneNumber == null || !mounted) return;

    setState(() => _updatingUserIds.add(userId));
    try {
      final result = await ApiService.linkWhatsAppNumber(
        userId: userId,
        phoneNumber: phoneNumber,
      );
      if (!mounted) return;
      setState(() {
        for (final item in _users) {
          if (item is! Map) continue;
          final itemId = item['id'] ?? item['user_id'];
          if (itemId.toString() == userId.toString()) {
            item['whatsapp_phone_number'] = result['phone_number'];
            break;
          }
        }
        _updatingUserIds.remove(userId);
      });
      _showMessage(result['message']?.toString() ?? 'WhatsApp number linked.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(userId));
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final userId = _userId(user);
    if (userId == null) {
      _showMessage('Could not identify this account.');
      return;
    }

    final name = (user['full_name'] ?? user['email'] ?? 'this user').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_rounded,
          color: Theme.of(dialogContext).colorScheme.error,
          size: 32,
        ),
        title: const Text('Delete user permanently?'),
        content: Text(
          'Delete $name and all tickets they created? This cannot be undone. '
          'Their assignments on other users’ tickets will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete user'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _updatingUserIds.add(userId);
      _deletingUserIds.add(userId);
    });
    try {
      final result = await ApiService.deleteUser(userId: userId);
      if (!mounted) return;
      setState(() {
        _users.removeWhere((item) {
          if (item is! Map) return false;
          final itemId = item['id'] ?? item['user_id'];
          return itemId.toString() == userId.toString();
        });
        _updatingUserIds.remove(userId);
        _deletingUserIds.remove(userId);
      });
      _showMessage(result['message']?.toString() ?? 'User deleted.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _updatingUserIds.remove(userId);
        _deletingUserIds.remove(userId);
      });
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _setUserLocked(
    Map<String, dynamic> user, {
    required bool locked,
  }) async {
    final userId = _userId(user);
    if (userId == null) {
      _showMessage('Could not identify this account.');
      return;
    }

    final name = (user['full_name'] ?? user['email'] ?? 'this user').toString();
    final action = locked ? 'Lock' : 'Unlock';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          locked ? Icons.lock_rounded : Icons.lock_open_rounded,
          color: Theme.of(dialogContext).colorScheme.primary,
          size: 30,
        ),
        title: Text('$action account?'),
        content: Text(
          locked
              ? 'Lock $name? They will not be able to sign in until an '
                    'administrator unlocks the account.'
              : 'Unlock $name and allow them to sign in again?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingUserIds.add(userId));
    try {
      final result = await ApiService.updateUserActiveStatus(
        userId: userId,
        isActive: !locked,
      );
      if (!mounted) return;
      setState(() {
        for (final item in _users) {
          if (item is! Map) continue;
          final itemId = item['id'] ?? item['user_id'];
          if (itemId.toString() == userId.toString()) {
            item['is_active'] = !locked;
            break;
          }
        }
        _updatingUserIds.remove(userId);
      });
      _showMessage(
        result['message']?.toString() ??
            'Account ${locked ? 'locked' : 'unlocked'}.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _updatingUserIds.remove(userId));
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  (Color, Color) _statusColors(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return (TdColors.resolvedBg, TdColors.resolvedFg);
      case 'rejected':
        return (TdColors.criticalBg, TdColors.criticalFg);
      case 'pending':
        return (TdColors.openBg, TdColors.openFg);
      default:
        return (TdColors.openBg, TdColors.openFg);
    }
  }

  (Color, Color) _roleColors(String role) {
    switch (role.toLowerCase()) {
      case 'technician':
        return (TdColors.progressBg, TdColors.progressFg);
      case 'administrator':
        return (TdColors.openBg, TdColors.openFg);
      default:
        return (TdColors.mint, TdColors.deepTeal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleUsers = _filteredUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Center(child: TdBackButton()),
        ),
        leadingWidth: 60,
        actions: [
          IconButton(
            tooltip: 'Refresh users',
            onPressed: _isLoading ? null : _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('User management', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'View registered accounts and manage registration approvals.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 16),
            if (!_isLoading && _errorMessage == null) ...[
              Row(
                children: [
                  Expanded(
                    child: _CountTile(
                      count: _countFor('All'),
                      label: 'Total',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CountTile(
                      count: _countFor('Pending'),
                      label: 'Pending',
                      highlight: _countFor('Pending') > 0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CountTile(
                      count: _countFor('Approved'),
                      label: 'Approved',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CountTile(
                      count: _countFor('Rejected'),
                      label: 'Rejected',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TdFilterChips(
                options: _filters,
                selected: _selectedFilter,
                counts: {for (final f in _filters) f: _countFor(f)},
                onSelected: (v) => setState(() => _selectedFilter = v),
              ),
              const SizedBox(height: 16),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              TdEmptyState(
                icon: Icons.error_outline_rounded,
                title: _errorMessage!,
                message: 'Please refresh the account list and try again.',
                actionLabel: 'Try again',
                onAction: _loadUsers,
              )
            else if (visibleUsers.isEmpty)
              TdEmptyState(
                icon: _selectedFilter == 'Pending'
                    ? Icons.verified_user_outlined
                    : Icons.people_outline_rounded,
                title: _selectedFilter == 'Pending'
                    ? 'No pending registrations'
                    : 'No ${_selectedFilter.toLowerCase()} users',
                message: 'Try another filter or refresh the list.',
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 2),
                child: Text(
                  '${visibleUsers.length} ${visibleUsers.length == 1 ? 'account' : 'accounts'}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              for (final user in visibleUsers) _buildUserCard(user),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.onSurfaceVariant;

    final name =
        (user['full_name'] ??
                user['name'] ??
                user['username'] ??
                'Unnamed user')
            .toString();
    final email = (user['email'] ?? 'No email provided').toString();
    final role = (user['role'] ?? 'Reporter').toString();
    final status = _approvalStatus(user);
    final userId = _userId(user);
    final isUpdating = userId != null && _updatingUserIds.contains(userId);
    final isDeleting = userId != null && _deletingUserIds.contains(userId);
    final currentUserId = ApiService.currentUser?['id'];
    final isCurrentUser = currentUserId?.toString() == userId?.toString();
    final isActive = user['is_active'] != false;
    final isPending = status.toLowerCase() == 'pending';
    final canLinkWhatsApp =
        role.toLowerCase() == 'reporter' && status.toLowerCase() == 'approved';
    final linkedWhatsAppNumber = user['whatsapp_phone_number']?.toString();
    final hasLinked =
        linkedWhatsAppNumber != null && linkedWhatsAppNumber.isNotEmpty;
    final (statusBg, statusFg) = _statusColors(status);
    final (roleBg, roleFg) = _roleColors(role);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending
              ? TdColors.amber.withValues(alpha: 0.45)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TdAvatar(initials: _initials(name), size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: secondaryColor, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TdPill(label: status, background: statusBg, foreground: statusFg),
            ],
          ),
          const SizedBox(height: 12),
          TdPill(
            label: role,
            background: roleBg,
            foreground: roleFg,
            showDot: false,
          ),
          if (!isActive) ...[
            const SizedBox(height: 8),
            TdPill(
              label: 'Locked',
              background: theme.colorScheme.errorContainer,
              foreground: theme.colorScheme.error,
              showDot: false,
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isUpdating || userId == null
                        ? null
                        : () => _updateApproval(user, 'Rejected'),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: TdColors.coral,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isUpdating || userId == null
                        ? null
                        : () => _updateApproval(user, 'Approved'),
                    icon: isUpdating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(isUpdating ? 'Updating...' : 'Approve'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (canLinkWhatsApp) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.chat_outlined,
                    size: 16, color: hasLinked ? TdColors.green : secondaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLinked
                        ? 'WhatsApp linked: $linkedWhatsAppNumber'
                        : 'No WhatsApp number linked',
                    style: TextStyle(color: secondaryColor, fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: isUpdating || userId == null
                      ? null
                      : () => _linkWhatsAppNumber(user),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 34),
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(hasLinked ? 'Change' : 'Link WhatsApp',
                          style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: isUpdating || userId == null || isCurrentUser
                    ? null
                    : () => _setUserLocked(user, locked: isActive),
                icon: Icon(
                  isActive
                      ? Icons.lock_outline_rounded
                      : Icons.lock_open_rounded,
                  size: 18,
                ),
                label: Text(isActive ? 'Lock account' : 'Unlock account'),
              ),
              OutlinedButton.icon(
                onPressed: isUpdating || userId == null || isCurrentUser
                    ? null
                    : () => _deleteUser(user),
                icon: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_forever_rounded, size: 18),
                label: Text(isCurrentUser ? 'Current account' : 'Delete user'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'TD';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length >= 2 ? 2 : 1)
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _CountTile extends StatelessWidget {
  final int count;
  final String label;
  final bool highlight;
  const _CountTile({
    required this.count,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? TdColors.openBg : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight
              ? TdColors.amber.withValues(alpha: 0.5)
              : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TdFonts.monoStyle.copyWith(
              fontSize: 20,
              color: highlight ? TdColors.openFg : theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: highlight ? TdColors.openFg : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppNumberDialog extends StatefulWidget {
  const _WhatsAppNumberDialog();

  @override
  State<_WhatsAppNumberDialog> createState() => _WhatsAppNumberDialogState();
}

class _WhatsAppNumberDialogState extends State<_WhatsAppNumberDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link WhatsApp number'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(
          labelText: 'Reporter phone number',
          hintText: '+254794045207',
          helperText: 'Use international format, starting with +.',
          errorText: _validationError,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            final phone = _controller.text.trim();
            if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
              setState(
                () => _validationError = 'Enter a valid international number.',
              );
              return;
            }
            Navigator.pop(context, phone);
          },
          child: const Text('Link number'),
        ),
      ],
    );
  }
}
