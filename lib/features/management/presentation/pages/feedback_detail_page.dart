import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/feedback_model.dart';
import 'package:aliolo/data/models/feedback_reply_model.dart';
import 'package:aliolo/data/services/feedback_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';

class FeedbackDetailPage extends StatefulWidget {
  final FeedbackModel feedback;

  const FeedbackDetailPage({super.key, required this.feedback});

  @override
  State<FeedbackDetailPage> createState() => _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends State<FeedbackDetailPage> {
  final _feedbackService = getIt<FeedbackService>();
  final _authService = getIt<AuthService>();
  final _replyController = TextEditingController();
  final _editController = TextEditingController();
  
  List<FeedbackReplyModel> _replies = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isEditingLast = false;
  late String _currentStatus;
  late String _originalContent;
  final List<XFile> _attachments = [];

  bool get _isAdmin => _authService.currentUser?.serverId == 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac';
  
  bool get _canReply {
    if (_isAdmin) return true;
    if (_currentStatus == 'closed') return false;
    
    // User can only reply if the status is 'replied' (meaning admin spoke last)
    return _currentStatus == 'replied';
  }

  bool get _isOwner => widget.feedback.userId == _authService.currentUser?.serverId;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.feedback.status;
    _originalContent = widget.feedback.content;
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _editController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    final results = await _feedbackService.getReplies(widget.feedback.id!);
    if (mounted) {
      setState(() {
        _replies = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    if (!_canReply) return;
    if (_replyController.text.trim().isEmpty && _attachments.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final reply = FeedbackReplyModel(
        feedbackId: widget.feedback.id!,
        userId: _authService.currentUser?.serverId ?? '',
        content: _replyController.text.trim(),
      );

      await _feedbackService.submitReply(reply, _attachments);
      _replyController.clear();
      _attachments.clear();
      await _loadReplies();
      // Status is automatically updated to 'open' (if user) or 'replied' (if admin) in the service
      _currentStatus = _isAdmin ? 'replied' : 'open';
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _saveEdit() async {
    final newContent = _editController.text.trim();
    if (newContent.isEmpty || newContent == (_replies.isEmpty ? _originalContent : _replies.last.content)) {
      setState(() => _isEditingLast = false);
      return;
    }

    setState(() => _isSending = true);
    try {
      if (_replies.isEmpty) {
        await _feedbackService.updateFeedbackContent(widget.feedback.id!, newContent);
        setState(() {
          _originalContent = newContent;
          _isEditingLast = false;
        });
      } else {
        await _feedbackService.updateReplyContent(_replies.last.id!, newContent);
        await _loadReplies();
        setState(() {
          _isEditingLast = false;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteLastReply() async {
    if (_replies.isEmpty) return; 

    setState(() => _isSending = true);
    try {
      await _feedbackService.deleteReply(_replies.last.id!);
      await _loadReplies();
      setState(() => _isEditingLast = false);
      
      // Update local status based on who is now the last speaker
      if (_replies.isEmpty) {
        _currentStatus = 'open'; // Original feedback
      } else {
        final lastReply = _replies.last;
        _currentStatus = (lastReply.userId == 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac') ? 'replied' : 'open';
      }
      await _feedbackService.updateFeedbackStatus(widget.feedback.id!, _currentStatus);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleStatus() async {
    final isClosing = _currentStatus == 'open' || _currentStatus == 'replied';
    String newStatus;

    if (isClosing) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Close Request?'),
          content: const Text('Are you sure you want to close this feedback request?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      newStatus = 'closed';
    } else {
      // Reopening: check who is the last speaker
      if (_replies.isEmpty) {
        newStatus = 'open'; // Original message from user
      } else {
        final lastReply = _replies.last;
        newStatus = (lastReply.userId == 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac') ? 'replied' : 'open';
      }
    }

    try {
      await _feedbackService.updateFeedbackStatus(widget.feedback.id!, newStatus);
      setState(() => _currentStatus = newStatus);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ThemeService().primaryColor;
    const appBarColor = Colors.white;

    return AlioloScrollablePage(
      title: Text(widget.feedback.title, style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold)),
      appBarColor: themeColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
        if (_isAdmin || _isOwner)
          TextButton(
            onPressed: _toggleStatus,
            child: Text(
              (_currentStatus == 'open' || _currentStatus == 'replied') ? 'CLOSE' : 'REOPEN',
              style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
            ),
          ),
      ],
      body: Column(
        children: [
          _buildOriginalFeedback(),
          const Divider(height: 32),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ..._replies.asMap().entries.map((entry) => _buildReplyCard(entry.value, entry.key == _replies.length - 1)),
          if (_canReply && !_isEditingLast) _buildReplyInput(),
          if (!_canReply && _currentStatus != 'closed' && !_isAdmin && !_isLoading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Please wait for a response before replying again.',
                style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOriginalFeedback() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    final isLastMessage = _replies.isEmpty;
    final isMyMessage = widget.feedback.userId == _authService.currentUser?.serverId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(status: _currentStatus),
                const Spacer(),
                if (isLastMessage && isMyMessage && !_isEditingLast && _currentStatus != 'closed')
                  IconButton(
                    icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                    onPressed: () {
                      _editController.text = _originalContent;
                      setState(() => _isEditingLast = true);
                    },
                  ),
                Text(widget.feedback.type.toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            if (_isEditingLast && isLastMessage)
              _buildEditInput(isReply: false)
            else
              Text(_originalContent, style: const TextStyle(fontSize: 16)),
            if (widget.feedback.attachmentUrls.isNotEmpty)
              _buildAttachments(widget.feedback.attachmentUrls),
            const Divider(height: 32),
            if (_isAdmin) ...[
              _buildDetailRow(Icons.person_outline, 'User',
                  '${widget.feedback.userName} (${widget.feedback.userEmail})', subColor),
              _buildDetailRow(Icons.badge_outlined, 'User ID',
                  widget.feedback.userId, subColor),
              if (widget.feedback.metadata['context'] != null)
                _buildDetailRow(Icons.folder_outlined, 'Context',
                    widget.feedback.metadata['context'], subColor),
              if (widget.feedback.metadata['subject_id'] != null)
                _buildDetailRow(Icons.tag, 'Subject ID',
                    widget.feedback.metadata['subject_id'], subColor),
              if (widget.feedback.metadata['folder_id'] != null)
                _buildDetailRow(Icons.tag, 'Folder ID',
                    widget.feedback.metadata['folder_id'], subColor),
              if (widget.feedback.metadata['collection_id'] != null)
                _buildDetailRow(Icons.tag, 'Collection ID',
                    widget.feedback.metadata['collection_id'], subColor),
              if (widget.feedback.metadata['card_id'] != null)
                _buildDetailRow(Icons.layers_outlined, 'Card ID',
                    widget.feedback.metadata['card_id'], subColor),
              
              // Rich Metadata for Admins
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text('TECHNICAL CONTEXT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: subColor, letterSpacing: 1.1)),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.computer, 'Platform', 
                  '${widget.feedback.metadata['platform'] ?? 'Unknown'} (v${widget.feedback.metadata['app_version'] ?? '?'})', subColor),
              
              if (widget.feedback.metadata['browser'] != null)
                _buildDetailRow(Icons.language, 'Browser', widget.feedback.metadata['browser'], subColor),
              
              if (widget.feedback.metadata['os_version'] != null)
                _buildDetailRow(Icons.settings_applications, 'OS Version', widget.feedback.metadata['os_version'], subColor),
              
              if (widget.feedback.metadata['device_model'] != null)
                _buildDetailRow(Icons.phone_android, 'Device', widget.feedback.metadata['device_model'], subColor),
              
              if (widget.feedback.metadata['distro'] != null)
                _buildDetailRow(Icons.terminal, 'Linux Distro', widget.feedback.metadata['distro'], subColor),

              if (widget.feedback.metadata['user_agent'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 14, color: subColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'UA: ${widget.feedback.metadata['user_agent']}',
                          style: TextStyle(fontSize: 10, color: subColor, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              if (widget.feedback.metadata['context'] != null)
                _buildDetailRow(Icons.folder_outlined, 'Context',
                    widget.feedback.metadata['context'], subColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditInput({bool isReply = true}) {
    return Column(
      children: [
        TextField(
          controller: _editController,
          maxLines: null,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onSubmitted: (_) => _saveEdit(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isReply)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                onPressed: _isSending ? null : _deleteLastReply,
                label: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() => _isEditingLast = false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSending ? null : _saveEdit,
              child: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyCard(FeedbackReplyModel reply, bool isLast) {
    final isMe = reply.userId == _authService.currentUser?.serverId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? ThemeService().primaryColor.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLast && isMe && !_isEditingLast && _currentStatus != 'closed')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 14, color: Colors.grey),
                    onPressed: () {
                      _editController.text = reply.content;
                      setState(() => _isEditingLast = true);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            if (_isEditingLast && isLast && isMe)
              _buildEditInput(isReply: true)
            else
              Text(reply.content),
            if (reply.attachmentUrls.isNotEmpty) _buildAttachments(reply.attachmentUrls),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              decoration: const InputDecoration(
                hintText: 'Type your reply...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendReply(),
            ),
          ),
          IconButton(
            icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
            onPressed: _sendReply,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(List<String> urls) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        children: urls.map((url) => GestureDetector(
          onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
          child: Tooltip(
            message: 'Click to view original',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (status == 'open') color = Colors.green;
    else if (status == 'replied') color = Colors.blue;
    else if (status == 'closed') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), 
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
