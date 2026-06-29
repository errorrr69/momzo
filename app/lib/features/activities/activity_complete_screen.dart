import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/env/app_env.dart';
import '../../core/theme/momzo_colors.dart';
import '../../core/theme/momzo_text.dart';
import '../../core/widgets/momzo_buttons.dart';
import '../../models/activity.dart';
import '../../services/activity_service.dart';
import '../../services/media_service.dart';

/// 16 · Did it · photo & note — optional keepsake that feeds the Memory Timeline.
/// Logs the completion to activity_logs (Task 18 + 28). The photo uploads to the
/// private family-media bucket; the note + photo path are saved on the log.
class ActivityCompleteScreen extends StatefulWidget {
  final Activity? activity;
  const ActivityCompleteScreen({super.key, this.activity});

  @override
  State<ActivityCompleteScreen> createState() => _ActivityCompleteScreenState();
}

class _ActivityCompleteScreenState extends State<ActivityCompleteScreen> {
  final _note = TextEditingController();
  bool _saving = false;
  bool _uploading = false;
  Uint8List? _photoPreview;
  String? _photoPath; // stored object path in family-media

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_uploading || !AppEnv.hasSupabase) return;
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _photoPreview = bytes;
        _uploading = true;
      });
      final path = await MediaService.upload(bytes, folder: 'activities');
      if (mounted) setState(() => _photoPath = path);
    } catch (_) {
      if (mounted) {
        setState(() => _photoPreview = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add the photo. The memory still saves.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _finish({required bool withNote}) async {
    if (_saving) return;
    final a = widget.activity;
    // Log the completion when connected and we have a real activity.
    if (AppEnv.hasSupabase && a != null) {
      setState(() => _saving = true);
      try {
        await ActivityService.logCompletion(
          activityId: a.id,
          note: withNote ? _note.text : null,
          photoUrl: withNote ? _photoPath : null,
        );
      } catch (_) {
        // Non-blocking — still return the mom to the list.
      }
    }
    if (!mounted) return;
    // Back to the activities list (pop the complete + detail screens).
    int popped = 0;
    Navigator.of(context).popUntil((_) => popped++ >= 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [MomzoColors.sageTint, MomzoColors.cream],
            stops: [0, .5],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(26, 20, 26, 8),
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: MomzoColors.sage,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: MomzoColors.sage.withOpacity(.4),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10)),
                              ],
                            ),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 38),
                          ),
                          const SizedBox(height: 16),
                          Text('You did it together 🌿', style: MomzoText.serif(26, color: MomzoColors.ink)),
                          const SizedBox(height: 6),
                          Text(
                            "Want to keep this little moment? It'll live in your Memory Timeline.",
                            textAlign: TextAlign.center,
                            style: MomzoText.sans(15, color: MomzoColors.body, weight: FontWeight.w400, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    // Photo: pick from gallery -> uploads to private family-media.
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        height: 150,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFC7DCCB), width: 2),
                        ),
                        child: _photoPreview != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(_photoPreview!, fit: BoxFit.cover),
                                  if (_uploading)
                                    Container(
                                      color: Colors.black26,
                                      child: const Center(
                                        child: CircularProgressIndicator(color: Colors.white),
                                      ),
                                    )
                                  else
                                    Positioned(
                                      right: 8, top: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                            color: Colors.white, shape: BoxShape.circle),
                                        child: const Icon(Icons.check_rounded,
                                            color: MomzoColors.sage, size: 16),
                                      ),
                                    ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: MomzoColors.sageTint,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.photo_camera_outlined,
                                        color: MomzoColors.sage, size: 24),
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Add a photo',
                                      style: MomzoText.sans(13,
                                          color: const Color(0xFF5C6B5F), weight: FontWeight.w700)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: MomzoColors.cardBorder, width: 1.5),
                      ),
                      child: TextField(
                        controller: _note,
                        minLines: 2,
                        maxLines: 4,
                        style: MomzoText.serif(15, color: MomzoColors.ink, height: 1.4),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'A few words to remember it by…',
                          hintStyle: MomzoText.serif(15, color: MomzoColors.muted, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 8, 26, 26),
                child: Row(
                  children: [
                    Expanded(
                      child: MomzoSecondaryButton('Skip', onTap: _saving ? null : () => _finish(withNote: false)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 14,
                      child: MomzoButton(_saving ? 'Saving…' : 'Save memory',
                          onTap: _saving ? null : () => _finish(withNote: true)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
