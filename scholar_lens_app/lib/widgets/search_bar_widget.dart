import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Search bar widget with gradient submit button.
/// Manages its own TextEditingController internally.
class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String hintText;

  const SearchBarWidget({
    super.key,
    required this.onSearch,
    this.hintText = 'Search papers… e.g. "deep learning"',
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSearch(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(60),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      padding: const EdgeInsets.only(left: 20, right: 6, top: 4, bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppTheme.textDim, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle:
                    const TextStyle(color: AppTheme.textDim, fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                isDense: true,
                filled: false,
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          // Gradient submit button
          GestureDetector(
            onTap: _submit,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                  Icons.arrow_forward, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
