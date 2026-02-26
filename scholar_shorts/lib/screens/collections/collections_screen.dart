import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../models/collection.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookmark_provider.dart';
import '../../theme/app_theme.dart';
import 'collection_detail_screen.dart';

/// Screen showing all user collections with paper counts.
class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  void _loadCollections() {
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      context.read<BookmarkProvider>().loadUserData(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildBody(),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppTheme.background.withValues(alpha: 0.9),
      title: Text(
        'My Collections',
        style: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
      centerTitle: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: AppTheme.textDim),
          onPressed: _loadCollections,
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Consumer<BookmarkProvider>(
      builder: (context, bookmark, _) {
        if (bookmark.isLoading && bookmark.collections.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accentTeal),
            ),
          );
        }

        if (bookmark.collections.isEmpty) {
          return SliverFillRemaining(
            child: _buildEmptyState(),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final collection = bookmark.collections[index];
                return _CollectionCard(
                  collection: collection,
                  onTap: () => _openCollection(collection),
                  onEdit: () => _showEditDialog(collection),
                  onDelete: () => _confirmDelete(collection),
                ).animate().fadeIn(
                    duration: 300.ms,
                    delay: Duration(milliseconds: index * 80),
                  ).slideY(begin: 0.1, end: 0);
              },
              childCount: bookmark.collections.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentTeal.withValues(alpha: 0.2),
                  AppTheme.accentSapphire.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: const Icon(
              Icons.collections_bookmark_rounded,
              size: 48,
              color: AppTheme.accentTeal,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No collections yet',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a collection to start saving papers',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppTheme.textDim,
            ),
          ),
          const SizedBox(height: 32),
          _buildCreateButton(),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _showCreateDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppTheme.auroraGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accentSapphire.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Create Collection',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFab() {
    return Consumer<BookmarkProvider>(
      builder: (context, bookmark, _) {
        if (bookmark.collections.isEmpty) return const SizedBox.shrink();
        return FloatingActionButton(
          onPressed: _showCreateDialog,
          backgroundColor: AppTheme.accentSapphire,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.5, 0.5));
      },
    );
  }

  // ─── Actions ──────────────────────────────────────────

  void _openCollection(Collection collection) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionDetailScreen(collection: collection),
      ),
    );
  }

  void _showCreateDialog() {
    _showCollectionFormDialog(title: 'New Collection');
  }

  void _showEditDialog(Collection collection) {
    _showCollectionFormDialog(
      title: 'Edit Collection',
      initialName: collection.name,
      initialDescription: collection.description,
      collectionId: collection.id,
    );
  }

  void _showCollectionFormDialog({
    required String title,
    String? initialName,
    String? initialDescription,
    String? collectionId,
  }) {
    final nameCtrl = TextEditingController(text: initialName ?? '');
    final descCtrl = TextEditingController(text: initialDescription ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
                border:
                    Border.all(color: AppTheme.glassBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textDim.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Collection Name',
                      hintText: 'e.g. AI Research',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'What kind of papers go here?',
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          _submitCollection(ctx, nameCtrl.text, descCtrl.text, collectionId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentSapphire,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        collectionId != null ? 'Update' : 'Create',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitCollection(
    BuildContext ctx,
    String name,
    String description,
    String? collectionId,
  ) async {
    if (name.trim().isEmpty) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    final bookmark = context.read<BookmarkProvider>();

    bool success;
    if (collectionId != null) {
      success = await bookmark.updateCollection(
        userId: userId,
        collectionId: collectionId,
        name: name.trim(),
        description: description.trim().isEmpty ? null : description.trim(),
      );
    } else {
      success = await bookmark.createCollection(
        userId: userId,
        name: name.trim(),
        description: description.trim().isEmpty ? null : description.trim(),
      );
    }

    if (success && ctx.mounted) {
      Navigator.pop(ctx);
    }
  }

  void _confirmDelete(Collection collection) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.glassBorder),
        ),
        title: Text(
          'Delete "${collection.name}"?',
          style: GoogleFonts.outfit(color: AppTheme.textPrimary),
        ),
        content: Text(
          'This will remove all ${collection.paperCount} saved papers in this collection. This action cannot be undone.',
          style: GoogleFonts.outfit(color: AppTheme.textDim, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textDim)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final userId = context.read<AuthProvider>().userId;
              if (userId == null) return;
              await context.read<BookmarkProvider>().deleteCollection(
                    userId: userId,
                    collectionId: collection.id,
                  );
            },
            child: Text('Delete',
                style: GoogleFonts.outfit(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// COLLECTION CARD WIDGET
// ═════════════════════════════════════════════════════════════════════════

class _CollectionCard extends StatelessWidget {
  final Collection collection;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CollectionCard({
    required this.collection,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.glassGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentTeal.withValues(alpha: 0.3),
                          AppTheme.accentSapphire.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        collection.isPrivate
                            ? Icons.lock_rounded
                            : Icons.public_rounded,
                        color: AppTheme.accentTeal,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          collection.description ?? '${collection.paperCount} papers',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.textDim,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Paper count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentSapphire.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${collection.paperCount}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                  ),
                  // Actions
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: AppTheme.textDim, size: 20),
                    color: AppTheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppTheme.glassBorder),
                    ),
                    onSelected: (val) {
                      if (val == 'edit') onEdit();
                      if (val == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: AppTheme.textDim),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
