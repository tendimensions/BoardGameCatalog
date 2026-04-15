import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/game_list.dart';
import '../providers/auth_provider.dart';
import '../providers/collection_provider.dart' show LoadState;
import '../providers/list_provider.dart';
import 'list_detail_screen.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final apiKey = context.read<AuthProvider>().apiKey;
    if (apiKey != null) {
      await context.read<ListProvider>().load(apiKey);
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text(
            'New List',
            style: TextStyle(color: Color(0xFFdddddd)),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Color(0xFFdddddd)),
                  decoration: _inputDecoration('List name *'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  style: const TextStyle(color: Color(0xFFdddddd)),
                  decoration: _inputDecoration('Description (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF666666))),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setSt(() => saving = true);
                      final apiKey = context.read<AuthProvider>().apiKey!;
                      final created =
                          await context.read<ListProvider>().createList(
                                apiKey,
                                nameCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                              );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (created == null && mounted) {
                        _showError(
                            context.read<ListProvider>().error ?? 'Error');
                      }
                    },
              child: Text(
                saving ? 'Saving…' : 'Create',
                style: const TextStyle(color: Color(0xFF7eb8f7)),
              ),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    descCtrl.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF5a1a1a),
      ),
    );
  }

  Future<void> _confirmDelete(GameList list) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'Delete list?',
          style: TextStyle(color: Color(0xFFdddddd)),
        ),
        content: Text(
          'Delete "${list.name}"? This cannot be undone.',
          style: const TextStyle(color: Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF666666))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFe57373))),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final apiKey = context.read<AuthProvider>().apiKey!;
    final ok2 =
        await context.read<ListProvider>().deleteList(apiKey, list.id);
    if (!ok2 && mounted) {
      _showError(context.read<ListProvider>().error ?? 'Error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ListProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      provider.loadState == LoadState.loaded
                          ? '${provider.lists.length} list${provider.lists.length == 1 ? '' : 's'}'
                          : 'Lists',
                      style: const TextStyle(
                          color: Color(0xFF666666), fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New List'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF7eb8f7),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    onPressed: _showCreateDialog,
                  ),
                ],
              ),
            ),

            // ── Error banner ─────────────────────────────────────────────
            if (provider.loadState == LoadState.error &&
                provider.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                color: const Color(0xFF2a1a00),
                child: Text(
                  provider.error!,
                  style: const TextStyle(
                      color: Color(0xFFffb74d), fontSize: 12),
                ),
              ),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(child: _buildBody(provider)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ListProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF7eb8f7)),
      );
    }

    if (provider.lists.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.list_alt_outlined,
                size: 64, color: Color(0xFF333333)),
            const SizedBox(height: 16),
            const Text(
              'No lists yet',
              style:
                  TextStyle(color: Color(0xFF666666), fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a list to organise your games.',
              style: TextStyle(color: Color(0xFF444444), fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create List'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7eb8f7),
                side: const BorderSide(color: Color(0xFF7eb8f7)),
              ),
              onPressed: _showCreateDialog,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF7eb8f7),
      backgroundColor: const Color(0xFF1a1a2e),
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: provider.lists.length,
        itemBuilder: (_, i) => _ListTile(
          list: provider.lists[i],
          onDelete: () => _confirmDelete(provider.lists[i]),
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  final GameList list;
  final VoidCallback onDelete;

  const _ListTile({required this.list, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2a2a2a)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF7eb8f7).withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.list_alt_outlined,
              color: Color(0xFF7eb8f7), size: 20),
        ),
        title: Text(
          list.name,
          style: const TextStyle(
            color: Color(0xFFdddddd),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          list.description.isEmpty
              ? '${list.entryCount} game${list.entryCount == 1 ? '' : 's'}'
              : '${list.entryCount} game${list.entryCount == 1 ? '' : 's'} · ${list.description}',
          style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right, color: Color(0xFF444444)),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFF5a2a2a), size: 20),
              onPressed: onDelete,
              tooltip: 'Delete list',
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListDetailScreen(
              listId: list.id,
              listName: list.name,
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF555555)),
      filled: true,
      fillColor: const Color(0xFF0f0f0f),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF7eb8f7)),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
