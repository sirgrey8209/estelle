import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/workspace_info.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../core/theme/app_colors.dart';

/// 새 워크스페이스 생성 다이얼로그
class NewWorkspaceDialog extends ConsumerStatefulWidget {
  final List<PylonWorkspaces> pylons;

  const NewWorkspaceDialog({super.key, required this.pylons});

  @override
  ConsumerState<NewWorkspaceDialog> createState() => _NewWorkspaceDialogState();
}

class _NewWorkspaceDialogState extends ConsumerState<NewWorkspaceDialog> {
  late int _selectedPylonIndex;
  late TextEditingController _nameController;
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _selectedPylonIndex = 0;
    _nameController = TextEditingController();

    // 초기 폴더 목록 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestFolderList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  PylonWorkspaces get _selectedPylon => widget.pylons[_selectedPylonIndex];

  void _requestFolderList({String? path}) {
    ref.read(folderListProvider.notifier).requestFolderList(
      _selectedPylon.deviceId,
      path: path,
    );
  }

  void _cyclePylon() {
    setState(() {
      _selectedPylonIndex = (_selectedPylonIndex + 1) % widget.pylons.length;
      _selectedFolder = null;
    });
    _requestFolderList();
  }

  void _goToParent(String currentPath) {
    // Windows 경로에서 상위 폴더 추출
    final parts = currentPath.split(RegExp(r'[/\\]'));
    if (parts.length > 1) {
      parts.removeLast();
      final parentPath = parts.join('\\');
      if (parentPath.isNotEmpty) {
        _requestFolderList(path: parentPath);
        setState(() => _selectedFolder = null);
      }
    }
  }

  void _selectFolder(String folderName) {
    setState(() {
      _selectedFolder = folderName;
      _nameController.text = folderName;
    });
  }

  void _enterFolder(String folderName) {
    final folderState = ref.read(folderListProvider);
    final fullPath = '${folderState.path}\\$folderName';

    _requestFolderList(path: fullPath);
    setState(() => _selectedFolder = null);
  }

  void _createFolder() {
    showDialog(
      context: context,
      builder: (context) => _CreateFolderDialog(
        onSubmit: (name) {
          final folderState = ref.read(folderListProvider);
          ref.read(folderListProvider.notifier).createFolder(
            _selectedPylon.deviceId,
            folderState.path,
            name,
          );
          // 새로고침
          Future.delayed(const Duration(milliseconds: 500), () {
            _requestFolderList(path: folderState.path);
          });
        },
      ),
    );
  }

  void _renameFolder(String folderName) {
    final folderState = ref.read(folderListProvider);
    final folderPath = '${folderState.path}\\$folderName';

    showDialog(
      context: context,
      builder: (context) => _RenameFolderDialog(
        currentName: folderName,
        onSubmit: (newName) {
          ref.read(folderListProvider.notifier).renameFolder(
            _selectedPylon.deviceId,
            folderPath,
            newName,
          );
          // 새로고침
          Future.delayed(const Duration(milliseconds: 500), () {
            _requestFolderList(path: folderState.path);
          });
        },
      ),
    );
  }

  void _createWorkspace() {
    final folderState = ref.read(folderListProvider);
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력하세요')),
      );
      return;
    }

    String workingDir;
    if (_selectedFolder != null) {
      workingDir = '${folderState.path}\\$_selectedFolder';
    } else {
      workingDir = folderState.path;
    }

    ref.read(pylonWorkspacesProvider.notifier).createWorkspace(
      _selectedPylon.deviceId,
      name,
      workingDir,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final folderState = ref.watch(folderListProvider);

    return Dialog(
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            _buildHeader(),

            const Divider(height: 1),

            // Pylon 선택 + 이름 입력
            _buildPylonAndName(),

            const Divider(height: 1),

            // 경로 표시
            _buildPathBar(folderState),

            const Divider(height: 1),

            // 폴더 목록
            Flexible(
              child: _buildFolderList(folderState),
            ),

            const Divider(height: 1),

            // 버튼
            _buildButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              '새 워크스페이스',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildPylonAndName() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Pylon 아이콘 버튼
          InkWell(
            onTap: widget.pylons.length > 1 ? _cyclePylon : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedPylon.icon.isNotEmpty ? _selectedPylon.icon : '',
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 이름 입력
          Expanded(
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '워크스페이스 이름',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathBar(FolderListState folderState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.folder, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              folderState.path,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: () => _goToParent(folderState.path),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: '상위 폴더',
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList(FolderListState folderState) {
    if (folderState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (folderState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            folderState.error!,
            style: const TextStyle(color: AppColors.statusError),
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      children: [
        // 폴더 목록
        for (final folder in folderState.folders)
          _FolderListTile(
            name: folder,
            isSelected: _selectedFolder == folder,
            onTap: () => _selectFolder(folder),
            onDoubleTap: () => _enterFolder(folder),
            onLongPress: () => _renameFolder(folder),
          ),

        // 새 폴더 버튼
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.create_new_folder, size: 20),
          title: const Text('새 폴더', style: TextStyle(fontSize: 14)),
          dense: true,
          onTap: _createFolder,
        ),
      ],
    );
  }

  Widget _buildButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _createWorkspace,
            child: const Text('생성'),
          ),
        ],
      ),
    );
  }
}

class _FolderListTile extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onLongPress;

  const _FolderListTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected ? AppColors.sidebarSelected : null,
        child: Row(
          children: [
            Icon(
              Icons.folder,
              size: 18,
              color: isSelected ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 18, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _CreateFolderDialog extends StatefulWidget {
  final Function(String) onSubmit;

  const _CreateFolderDialog({required this.onSubmit});

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 폴더'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '폴더 이름',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('생성'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) {
      widget.onSubmit(name);
      Navigator.of(context).pop();
    }
  }
}

class _RenameFolderDialog extends StatefulWidget {
  final String currentName;
  final Function(String) onSubmit;

  const _RenameFolderDialog({
    required this.currentName,
    required this.onSubmit,
  });

  @override
  State<_RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<_RenameFolderDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('폴더 이름 변경'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '새 이름',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('변경'),
        ),
      ],
    );
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty && name != widget.currentName) {
      widget.onSubmit(name);
      Navigator.of(context).pop();
    }
  }
}
