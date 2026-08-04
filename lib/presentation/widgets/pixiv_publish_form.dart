import 'package:flutter/material.dart';

import '../../domain/entities/pixiv_upload_task.dart';
import '../controllers/pixiv_settings_controller.dart';
import 'pixiv_attributes_card.dart';
import 'pixiv_ratings_card.dart';
import 'pixiv_visibility_card.dart';

/// Collected, validated values from [PixivPublishForm].
class PixivPublishFormValues {
  const PixivPublishFormValues({
    required this.title,
    required this.caption,
    required this.tags,
    required this.xRestrict,
    required this.aiType,
    required this.restrict,
    required this.allowComment,
    required this.sexual,
    required this.attributes,
    required this.ratings,
    required this.responseAutoAccept,
    required this.original,
  });

  final String title;
  final String caption;
  final List<String> tags;
  final PixivXRestrict xRestrict;
  final PixivAiType aiType;
  final PixivRestrict restrict;
  final bool allowComment;
  final bool sexual;
  final PixivAttributes attributes;
  final PixivRatings ratings;
  final bool responseAutoAccept;
  final bool original;
}

/// All user-editable Pixiv publication fields, grouped into cards mirroring
/// the official Pixiv app upload UI. State lives here so the host page stays
/// under the 500-line limit (rules.md §3.1).
class PixivPublishForm extends StatefulWidget {
  const PixivPublishForm({super.key, required this.settingsController});

  final PixivSettingsController settingsController;

  @override
  State<PixivPublishForm> createState() => PixivPublishFormState();
}

class PixivPublishFormState extends State<PixivPublishForm> {
  late final TextEditingController _title;
  late final TextEditingController _caption;
  late final TextEditingController _tags;

  late PixivXRestrict _xRestrict;
  late PixivAiType _aiType;
  late PixivRestrict _restrict;
  late bool _allowComment;
  late bool _sexual;
  late PixivAttributes _attributes;
  late PixivRatings _ratings;
  late bool _responseAutoAccept;
  late bool _original;

  @override
  void initState() {
    super.initState();
    final s = widget.settingsController.settings;
    _title = TextEditingController();
    _caption = TextEditingController(text: s.captionPrefix);
    _tags = TextEditingController(text: s.defaultTags.join(', '));
    _xRestrict = s.xRestrictDefault;
    _aiType = s.aiTypeDefault;
    _restrict = s.restrictDefault;
    _allowComment = s.allowCommentDefault;
    _sexual = s.sexualDefault;
    _attributes = s.attributesDefault;
    _ratings = s.ratingsDefault;
    _responseAutoAccept = s.responseAutoAcceptDefault;
    _original = s.originalDefault;
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    _tags.dispose();
    super.dispose();
  }

  /// Splits a raw tag string on both ASCII and full-width commas.
  List<String> _parseTags(String raw) {
    return raw
        .split(RegExp(r'[,，]'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Snapshot of the current field values for submission.
  PixivPublishFormValues collect() {
    // Pixiv forces sexual=false for all-ages works.
    final effectiveSexual = _xRestrict == PixivXRestrict.general
        ? false
        : _sexual;
    return PixivPublishFormValues(
      title: _title.text.trim(),
      caption: _caption.text.trim(),
      tags: _parseTags(_tags.text),
      xRestrict: _xRestrict,
      aiType: _aiType,
      restrict: _restrict,
      allowComment: _allowComment,
      sexual: effectiveSexual,
      attributes: _attributes,
      ratings: _ratings,
      responseAutoAccept: _responseAutoAccept,
      original: _original,
    );
  }

  /// Restore defaults so the user can queue another artwork.
  void reset() {
    final s = widget.settingsController.settings;
    _title.clear();
    _caption.text = s.captionPrefix;
    _tags.text = s.defaultTags.join(', ');
    setState(() {
      _xRestrict = s.xRestrictDefault;
      _aiType = s.aiTypeDefault;
      _restrict = s.restrictDefault;
      _allowComment = s.allowCommentDefault;
      _sexual = s.sexualDefault;
      _attributes = s.attributesDefault;
      _ratings = s.ratingsDefault;
      _responseAutoAccept = s.responseAutoAcceptDefault;
      _original = s.originalDefault;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _basicCard(context),
        const SizedBox(height: 12),
        PixivVisibilityCard(
          xRestrict: _xRestrict,
          aiType: _aiType,
          restrict: _restrict,
          allowComment: _allowComment,
          sexual: _sexual,
          responseAutoAccept: _responseAutoAccept,
          original: _original,
          onXRestrictChanged: (v) => setState(() => _xRestrict = v),
          onAiTypeChanged: (v) => setState(() => _aiType = v),
          onRestrictChanged: (v) => setState(() => _restrict = v),
          onAllowCommentChanged: (v) => setState(() => _allowComment = v),
          onSexualChanged: (v) => setState(() => _sexual = v),
          onResponseAutoAcceptChanged: (v) =>
              setState(() => _responseAutoAccept = v),
          onOriginalChanged: (v) => setState(() => _original = v),
        ),
        const SizedBox(height: 12),
        PixivAttributesCard(
          attributes: _attributes,
          onChanged: (v) => setState(() => _attributes = v),
        ),
        const SizedBox(height: 12),
        PixivRatingsCard(
          ratings: _ratings,
          onChanged: (v) => setState(() => _ratings = v),
        ),
      ],
    );
  }

  Widget _basicCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: '标题',
                helperText: '最多 32 字',
                border: OutlineInputBorder(),
              ),
              maxLength: 32,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _caption,
              decoration: const InputDecoration(
                labelText: '正文',
                helperText: '最多 3000 字',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 3000,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: '标签 (逗号分隔，最多 10 个)',
                helperText: '支持中英文逗号',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
