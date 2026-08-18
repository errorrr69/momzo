import 'package:flutter/material.dart';

import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../models/forum.dart';
import '../../services/forum_service.dart';

/// Writing a new thread.
class NewThreadScreen extends StatefulWidget {
  final ForumCategory category;

  /// Seeded when she arrives from "Talk about this in the Circle". A starting
  /// point she is free to delete — the BODY is deliberately left empty, because
  /// prefilling that would be putting words in her mouth.
  final String? initialTitle;

  const NewThreadScreen({super.key, required this.category, this.initialTitle});

  @override
  State<NewThreadScreen> createState() => _NewThreadScreenState();
}

class _NewThreadScreenState extends State<NewThreadScreen> {
  late final _title = TextEditingController(text: widget.initialTitle ?? '');
  final _body = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.length < 3) {
      setState(() => _error = 'A few more words in the title?');
      return;
    }
    if (body.isEmpty) {
      setState(() => _error = 'Tell them a little more.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await ForumService.post(categoryId: widget.category.id, title: title, body: body);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() { _saving = false; _error = 'That didn’t send. Try again in a moment?'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MomzoColors.cream,
      appBar: AppBar(
        backgroundColor: MomzoColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: MomzoColors.ink),
        title: Text('In ${widget.category.title}',
            style: MomzoText.sans(15, color: MomzoColors.muted, weight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _post,
            child: Text('Post',
                style: MomzoText.sans(15,
                    color: _saving ? MomzoColors.faint : MomzoColors.coral,
                    weight: FontWeight.w800)),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          children: [
            TextField(
              controller: _title,
              maxLength: 140,
              textCapitalization: TextCapitalization.sentences,
              style: MomzoText.serif(21, color: MomzoColors.ink, height: 1.3),
              decoration: InputDecoration(
                hintText: 'What’s on your mind?',
                hintStyle: MomzoText.serif(21, color: MomzoColors.faint),
                counterText: '',
                border: InputBorder.none,
              ),
            ),
            const Divider(color: MomzoColors.hairline),
            TextField(
              controller: _body,
              maxLines: null,
              minLines: 6,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              style: MomzoText.sans(15,
                  color: MomzoColors.body, weight: FontWeight.w600, height: 1.55),
              decoration: InputDecoration(
                hintText: 'However it comes out is fine.',
                hintStyle: MomzoText.sans(15, color: MomzoColors.faint),
                counterText: '',
                border: InputBorder.none,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: MomzoText.sans(13,
                      color: MomzoColors.coralDeep, weight: FontWeight.w700)),
            ],
            const SizedBox(height: 14),
            // The one rule that protects somebody who isn't in the room.
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: MomzoColors.honeyTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'A gentle reminder: no full names, schools, or anything that would '
                'identify your child.',
                style: MomzoText.sans(12.5,
                    color: MomzoColors.honeyText, weight: FontWeight.w700, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
