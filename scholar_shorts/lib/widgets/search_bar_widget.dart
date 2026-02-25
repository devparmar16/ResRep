import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Search bar widget with gradient submit button.
/// Manages its own TextEditingController internally.
class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String hintText;
  final bool isLoading;

  const SearchBarWidget({
    super.key,
    required this.onSearch,
    this.hintText = 'Search papers… e.g. "deep learning"',
    this.isLoading = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  final _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.isLoading) return;
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSearch(text);
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20), // More square 'Lens' aesthetic
        border: Border.all(
          color: _isFocused ? AppTheme.accentTeal : AppTheme.glassBorder,
          width: _isFocused ? 1.5 : 1.0,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: AppTheme.accentTeal.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : [
                 BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      padding: const EdgeInsets.only(left: 16, right: 6, top: 4, bottom: 4),
      child: Row(
        children: [
          Icon(
            Icons.lens_blur_rounded, // Lens icon
            color: _isFocused ? AppTheme.accentTeal : AppTheme.textDim,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle:
                    TextStyle(color: AppTheme.textDim.withValues(alpha: 0.7), fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                isDense: true,
                filled: false,
              ),
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.search,
            ),
          ),
          const SizedBox(width: 8),
          // Gradient submit button (Aurora)
          GestureDetector(
            onTap: _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: widget.isLoading ? null : AppTheme.auroraGradient,
                color: widget.isLoading ? AppTheme.surfaceVariant : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: widget.isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: AppTheme.accentSapphire.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              child: widget.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.textDim,
                      ),
                    )
                  : const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
