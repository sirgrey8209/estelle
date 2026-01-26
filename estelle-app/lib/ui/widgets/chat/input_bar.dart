import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/colors.dart';
import '../../../state/providers/workspace_provider.dart';
import '../../../state/providers/claude_provider.dart';
import '../../../state/providers/relay_provider.dart';

/// 첨부 이미지 상태
final attachedImageProvider = StateProvider<File?>((ref) => null);

class InputBar extends ConsumerStatefulWidget {
  const InputBar({super.key});

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  bool get _isMobile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _showAttachMenu() async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopLayout = screenWidth >= 600;

    if (isDesktopLayout || _isDesktop) {
      // 데스크탑: 팝업 메뉴
      _showDesktopMenu();
    } else {
      // 모바일: 바텀 시트
      _showMobileSheet();
    }
  }

  void _showDesktopMenu() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          button.localToGlobal(Offset.zero, ancestor: overlay),
          button.localToGlobal(button.size.bottomLeft(Offset.zero), ancestor: overlay),
        ),
        Offset.zero & overlay.size,
      ),
      color: NordColors.nord2,
      items: [
        const PopupMenuItem(
          value: 'gallery',
          child: Row(
            children: [
              Icon(Icons.photo_library, color: NordColors.nord8, size: 20),
              SizedBox(width: 12),
              Text('이미지 선택', style: TextStyle(color: NordColors.nord5)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'gallery') {
        _pickImage(ImageSource.gallery);
      }
    });
  }

  void _showMobileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: NordColors.nord1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: NordColors.nord8),
                title: const Text('갤러리에서 선택', style: TextStyle(color: NordColors.nord5)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_isMobile)
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: NordColors.nord9),
                  title: const Text('카메라 촬영', style: TextStyle(color: NordColors.nord5)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        ref.read(attachedImageProvider.notifier).state = File(image.path);
      }
    } catch (e) {
      print('Image pick error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미지를 선택할 수 없습니다: $e'),
            backgroundColor: NordColors.nord11,
          ),
        );
      }
    }
  }

  void _removeAttachment() {
    ref.read(attachedImageProvider.notifier).state = null;
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final attachedImage = ref.read(attachedImageProvider);

    // 텍스트나 이미지 둘 다 없으면 리턴
    if (text.isEmpty && attachedImage == null) return;

    final selectedItem = ref.read(selectedItemProvider);
    final selectedWorkspace = ref.read(selectedWorkspaceProvider);
    if (selectedItem == null || selectedWorkspace == null) return;
    if (!selectedItem.isConversation) return;

    // 작업 중이면 전송 안함
    final claudeState = ref.read(claudeStateProvider);
    if (claudeState == 'working') return;

    setState(() => _isUploading = true);

    try {
      // 이미지가 있으면 Blob 업로드 (Pylon에서 Claude로 메시지 전달)
      if (attachedImage != null) {
        final blobService = ref.read(blobTransferServiceProvider);

        // 동일 PC 여부 확인 (Pylon과 클라이언트가 같은 PC)
        // TODO: 실제로는 Pylon의 deviceId와 비교 필요
        final sameDevice = _isDesktop;

        // 전송 중 placeholder 표시
        ref.read(sendingMessageProvider.notifier).state = text.isNotEmpty ? text : '(이미지 전송)';

        await blobService.uploadImage(
          file: attachedImage,
          targetDeviceId: selectedItem.deviceId,
          deskId: selectedItem.workspaceId,
          conversationId: selectedItem.itemId,
          message: text,
          sameDevice: sameDevice,
        );

        // 첨부 이미지 제거
        ref.read(attachedImageProvider.notifier).state = null;

        // Blob 전송 시 Pylon의 blob_end 핸들러에서 Claude로 메시지 전달하므로
        // 여기서는 sendClaudeMessage 호출하지 않음
      } else {
        // 텍스트만 있는 경우
        // 전송 중 placeholder 표시
        ref.read(sendingMessageProvider.notifier).state = text;

        // Send to relay
        ref.read(relayServiceProvider).sendClaudeMessage(
          selectedItem.deviceId,
          selectedItem.workspaceId,
          selectedItem.itemId,
          text,
        );
      }

      // Update state
      ref.read(claudeStateProvider.notifier).state = 'working';
      ref.read(isThinkingProvider.notifier).state = true;
      ref.read(workStartTimeProvider.notifier).state = DateTime.now();

      // Clear input
      _controller.clear();
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _stop() {
    final selectedItem = ref.read(selectedItemProvider);
    if (selectedItem == null || !selectedItem.isConversation) return;

    ref.read(relayServiceProvider).sendClaudeControl(
      selectedItem.deviceId,
      selectedItem.workspaceId,
      selectedItem.itemId,
      'stop',
    );
  }

  @override
  Widget build(BuildContext context) {
    final claudeState = ref.watch(claudeStateProvider);
    final isWorking = claudeState == 'working';
    final attachedImage = ref.watch(attachedImageProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 첨부 이미지 미리보기
        if (attachedImage != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            decoration: const BoxDecoration(
              color: NordColors.nord1,
              border: Border(
                top: BorderSide(color: NordColors.nord2),
              ),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        attachedImage,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: GestureDetector(
                        onTap: _removeAttachment,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: NordColors.nord11,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: NordColors.nord6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    attachedImage.path.split('/').last,
                    style: const TextStyle(
                      color: NordColors.nord4,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // 입력 바
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            color: NordColors.nord1,
            border: Border(
              top: BorderSide(color: NordColors.nord2),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // + 버튼
              IconButton(
                onPressed: _isUploading ? null : _showAttachMenu,
                icon: const Icon(Icons.add_circle_outline),
                color: NordColors.nord8,
                iconSize: 24,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),

              // 텍스트 입력
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isDesktopLayout = screenWidth >= 600;

                    if (isDesktopLayout &&
                        event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed &&
                        !HardwareKeyboard.instance.isControlPressed) {
                      _send();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !_isUploading,
                      maxLines: null,
                      minLines: 1,
                      scrollPhysics: const BouncingScrollPhysics(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: NordColors.nord5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: NordColors.nord3),
                        filled: true,
                        fillColor: NordColors.nord0,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: NordColors.nord2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: NordColors.nord2),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: NordColors.nord9),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 전송/중지 버튼
              if (_isUploading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NordColors.nord8,
                  ),
                )
              else if (isWorking)
                ElevatedButton(
                  onPressed: _stop,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NordColors.nord11,
                    foregroundColor: NordColors.nord6,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Stop'),
                )
              else
                ElevatedButton(
                  onPressed: (!_hasText && attachedImage == null) ? null : _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NordColors.nord10,
                    foregroundColor: NordColors.nord6,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Send'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
