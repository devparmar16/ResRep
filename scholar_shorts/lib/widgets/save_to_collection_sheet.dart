import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../models/paper.dart';
import '../providers/auth_provider.dart';
import '../providers/bookmark_provider.dart';
import '../services/bookmark_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that shows user's collections and lets them
/// save/unsave the current paper to any collection.
/// Also offers inline "Quick Create" for a new collection.
class SaveToCollectionSheet extends StatefulWidget {
  final Paper paper;

  const SaveToCollectionSheet({super.key, required this.paper});

  /// Show the save-to-collection bottom sheet.
  static Future<void> show(BuildContext context, Paper paper) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SaveToCollectionSheet(paper: paper),
    );
  }

  @override
  State<SaveToCollectionSheet> createState() => _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends State<SaveToCollectionSheet> {
  Set<String> _savedInCollections = {};
  bool _loadingIds = true;
  bool _showCreate = false;
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final service = context.read<BookmarkProvider>();

    // Ensure collections are loaded
    if (service.collections.isEmpty) {
      await service.loadUserData(userId);
    }

    // Check which collections already contain this paper
    final ids = await service._getCollectionIdsForPaper(userId, widget.paper.paperId);
    if (mounted) {
      setState(() {
        _savedInCollections = ids.toSet();
        _loadingIds = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, scrollCtrl) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.95),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              children: [
                _buildHandle(),
                _buildTitle(),
                const Divider(color: AppTheme.glassBorder, height: 1),
                Expanded(child: _buildList(scrollCtrl)),
                if (_showCreate) _buildInlineCreate(),
                _buildBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.textDim.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Row(
        children: [
          const Icon(Icons.bookmark_add_rounded,
              color: AppTheme.accentTeal, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Save to Collection',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ScrollController scrollCtrl) {
    return Consumer<BookmarkProvider>(
      builder: (context, bm, _) {
        if (_loadingIds || bm.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.accentTeal),
          );
        }

        if (bm.collections.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_off_rounded,
                    size: 40,
                    color: AppTheme.textDim.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(
                  'No collections yet',
                  style: GoogleFonts.outfit(
                      fontSize: 15, color: AppTheme.textDim),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: bm.collections.length,
          itemBuilder: (_, i) {
            final col = bm.collections[i];
            final isSaved = _savedInCollections.contains(col.id);

            return _CollectionRow(
              name: col.name,
              paperCount: col.paperCount,
              isSaved: isSaved,
              onTap: () => _toggleSave(col.id, isSaved),
            ).animate().fadeIn(
                  duration: 200.ms,
                  delay: Duration(milliseconds: i * 40),
                );
          },
        );
      },
    );
  }

  Widget _buildInlineCreate() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.7),
        border: const Border(top: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              autofocus: true,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'New collection name…',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.glassBorder),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded,
                color: AppTheme.accentTeal, size: 28),
            onPressed: _createAndSave,
          ),
          IconButton(
            icon: Icon(Icons.cancel_rounded,
                color: AppTheme.textDim.withValues(alpha: 0.5), size: 28),
            onPressed: () => setState(() => _showCreate = false),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2);
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
        border: const Border(top: BorderSide(color: AppTheme.glassBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showCreate = !_showCreate),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accentTeal.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        color: AppTheme.accentTeal, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'New Collection',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.auroraGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────

  Future<void> _toggleSave(String collectionId, bool currentlySaved) async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final bm = context.read<BookmarkProvider>();
    final p = widget.paper;

    if (currentlySaved) {
      final ok = await bm.removePaper(
        userId: userId,
        collectionId: collectionId,
        openalexId: p.paperId,
      );
      if (ok && mounted) {
        setState(() => _savedInCollections.remove(collectionId));
      }
    } else {
      final ok = await bm.savePaper(
        userId: userId,
        collectionId: collectionId,
        openalexId: p.paperId,
        title: p.title,
        journalName: p.journal,
        publicationDate: p.publicationDate,
        isOpenAccess: p.isOpenAccess,
      );
      if (ok && mounted) {
        setState(() => _savedInCollections.add(collectionId));
      }
    }
  }

  Future<void> _createAndSave() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final bm = context.read<BookmarkProvider>();

    final ok = await bm.createCollection(userId: userId, name: name);
    if (ok && mounted) {
      // Save paper to the newly created collection
      final newCol = bm.collections.first; // Just created, at index 0
      await _toggleSave(newCol.id, false);
      setState(() {
        _showCreate = false;
        _nameCtrl.clear();
      });
    }
  }
}

// Helper extension to access service method from provider
extension _BookmarkProviderExt on BookmarkProvider {
  Future<List<String>> _getCollectionIdsForPaper(
      String userId, String openalexId) async {
    final service = BookmarkService();
    return service.getSavedCollectionIds(
      userId: userId,
      openalexId: openalexId,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// COLLECTION ROW
// ═════════════════════════════════════════════════════════════════════════

class _CollectionRow extends StatelessWidget {
  final String name;
  final int paperCount;
  final bool isSaved;
  final VoidCallback onTap;

  const _CollectionRow({
    required this.name,
    required this.paperCount,
    required this.isSaved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSaved
                  ? AppTheme.accentTeal.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSaved
                    ? AppTheme.accentTeal.withValues(alpha: 0.3)
                    : AppTheme.glassBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSaved
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSaved ? AppTheme.accentTeal : AppTheme.textDim,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '$paperCount papers',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppTheme.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
