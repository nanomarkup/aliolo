import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/feedback_model.dart';
import 'package:aliolo/data/services/feedback_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';

class FeedbackPage extends StatefulWidget {
  final String? subjectId;
  final String? cardId;
  final String? contextTitle;
  final Color? appBarColor;

  const FeedbackPage({
    super.key,
    this.subjectId,
    this.cardId,
    this.contextTitle,
    this.appBarColor,
  });

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _feedbackService = getIt<FeedbackService>();
  final _authService = getIt<AuthService>();

  String _selectedType = 'bug';
  final List<XFile> _attachments = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Use pickMultiImage to allow multiple selection and ensure only images
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 70, // Optimize size
    );
    
    if (images.isNotEmpty) {
      setState(() {
        _attachments.addAll(images);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final feedback = FeedbackModel(
        userId: _authService.currentUser?.serverId ?? '',
        type: _selectedType,
        title: _titleController.text,
        content: _contentController.text,
        subjectId: widget.subjectId,
        cardId: widget.cardId,
        metadata: {
          'platform': Theme.of(context).platform.toString(),
          'context': widget.contextTitle,
        },
      );

      await _feedbackService.submitFeedback(feedback, _attachments);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('feedback_success'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.t('feedback_error')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const iconColor = Colors.white;

    return AlioloScrollablePage(
      title: Text(
        context.t('feedback_title'),
        style: const TextStyle(color: iconColor, fontWeight: FontWeight.bold),
      ),
      appBarColor: widget.appBarColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: iconColor),
          onPressed: () => Navigator.pop(context),
        ),
        if (_isSubmitting)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                ),
              ),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.send, color: iconColor),
            onPressed: _submit,
          ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.contextTitle != null) ...[
              Text(
                '${context.t('feedback_context')}: ${widget.contextTitle}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: context.t('feedback_type'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'bug', child: Text(context.t('feedback_bug'))),
                DropdownMenuItem(value: 'suggestion', child: Text(context.t('feedback_suggestion'))),
                DropdownMenuItem(value: 'other', child: Text(context.t('feedback_other'))),
              ],
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: context.t('feedback_title_hint'),
                border: const OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.t('feedback_details'),
                border: const OutlineInputBorder(),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            Text(
              context.t('feedback_attachments'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._attachments.map((file) => Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(file.path, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image)),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _attachments.remove(file)),
                            child: Container(
                              color: Colors.black54,
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    )),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
