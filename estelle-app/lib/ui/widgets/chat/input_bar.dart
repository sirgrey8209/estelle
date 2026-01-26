import 'dart:async';
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
import '../../../state/providers/image_upload_provider.dart';
import '../../../data/services/blob_transfer_service.dart';

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
  StreamSubscription? _completeSubscription;
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _setupBlobListeners();
  }

  void _setupBlobListeners() {
    final blobService = ref.read(blobTransferServiceProvider);

    // 업로드 완료 리스너
    _completeSubscription = blobService.completeStream.listen((event) {
      // 업로드 완료 시 Provider 업데이트
      ref.read(imageUploadProvider.notifier).completeUpload(
        event.blobId,
        event.pylonPath,
      );

      // 큐에 대기 중인 메시지가 있으면 전송
      _processMessageQueue();
    });

    // 프로그레스 및 실패 리스너
    _progressSubscription = blobService.progressStream.listen((transfer) {
      if (transfer.state == BlobTransferState.failed) {
        // 실패 시 Provider 업데이트
        ref.read(imageUploadProvider.notifier).failUpload(
          transfer.blobId,
          transfer.error ?? '업로드 실패',
        );

        // 잠시 후 업로드 정보 제거 (버블 삭제)
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            ref.read(imageUploadProvider.notifier).removeUpload(transfer.blobId);
          }
        });
      } else {
        // 프로그레스 업데이트
        ref.read(imageUploadProvider.notifier).updateProgress(
          transfer.blobId,
          transfer.sentChunks,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _completeSubscription?.cancel();
    _progressSubscription?.cancel();
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
      _showDesktopMenu();
    } else {
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
    final uploadState = ref.read(imageUploadProvider);

    // 텍스트나 이미지 둘 다 없으면 리턴
    if (text.isEmpty && attachedImage == null) return;

    final selectedItem = ref.read(selectedItemProvider);
    final selectedWorkspace = ref.read(selectedWorkspaceProvider);
    if (selectedItem == null || selectedWorkspace == null) return;
    if (!selectedItem.isConversation) return;

    // 작업 중이면 전송 안함
    final claudeState = ref.read(claudeStateProvider);
    if (claudeState == 'working') return;

    // 업로드 중이면 메시지를 큐에 넣음
    if (uploadState.hasActiveUpload) {
      if (text.isNotEmpty) {
        ref.read(imageUploadProvider.notifier).queueMessage(text);
        _controller.clear();
      }
      return;
    }

    // 이미지가 있으면 업로드 시작
    if (attachedImage != null) {
      await _startImageUpload(attachedImage, text);
      _controller.clear();
      ref.read(attachedImageProvider.notifier).state = null;
    } else {
      // 텍스트만 있는 경우
      _sendTextMessage(text);
      _controller.clear();
    }
  }

  Future<void> _startImageUpload(File image, String text) async {
    final selectedItem = ref.read(selectedItemProvider);
    if (selectedItem == null) return;

    final blobService = ref.read(blobTransferServiceProvider);
    final sameDevice = _isDesktop;

    // 업로드 시작
    final blobId = await blobService.uploadImage(
      file: image,
      targetDeviceId: selectedItem.deviceId,
      deskId: selectedItem.workspaceId,
      conversationId: selectedItem.itemId,
      message: text.isEmpty ? null : text,
      sameDevice: sameDevice,
    );

    if (blobId != null) {
      final transfer = blobService.getTransfer(blobId);
      if (transfer != null) {
        // Provider에 업로드 정보 등록
        ref.read(imageUploadProvider.notifier).startUpload(
          blobId: blobId,
          localPath: transfer.localPath ?? '',
          filename: transfer.filename,
          totalChunks: transfer.totalChunks,
          conversationId: selectedItem.itemId,
          message: text.isEmpty ? null : text,
        );
      }

      // 함께 보낸 텍스트가 있으면 큐에 추가
      if (text.isNotEmpty) {
        ref.read(imageUploadProvider.notifier).queueMessage(text);
      }
    }
  }

  void _sendTextMessage(String text) {
    final selectedItem = ref.read(selectedItemProvider);
    if (selectedItem == null) return;

    // 최근 이미지 경로들 가져오기
    final imagePaths = ref.read(imageUploadProvider.notifier).consumeRecentImagePaths();

    // 이미지 경로가 있으면 메시지에 포함
    String messageToSend = text;
    if (imagePaths.isNotEmpty) {
      final imageRefs = imagePaths.map((p) => '[image:$p]').join('\n');
      messageToSend = '$imageRefs\n$text';
    }

    ref.read(sendingMessageProvider.notifier).state = text;

    ref.read(relayServiceProvider).sendClaudeMessage(
      selectedItem.deviceId,
      selectedItem.workspaceId,
      selectedItem.itemId,
      messageToSend,
    );

    ref.read(claudeStateProvider.notifier).state = 'working';
    ref.read(isThinkingProvider.notifier).state = true;
    ref.read(workStartTimeProvider.notifier).state = DateTime.now();
  }

  void _processMessageQueue() {
    final uploadState = ref.read(imageUploadProvider);

    // 아직 업로드 중이면 대기
    if (uploadState.hasActiveUpload) return;

    // 큐에서 메시지 꺼내서 전송
    final queued = ref.read(imageUploadProvider.notifier).dequeueMessage();
    if (queued != null) {
      _sendTextMessage(queued.text);
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
    final uploadState = ref.watch(imageUploadProvider);
    final isBusy = uploadState.isBusy;

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
                onPressed: isBusy ? null : _showAttachMenu,
                icon: const Icon(Icons.add_circle_outline),
                color: isBusy ? NordColors.nord3 : NordColors.nord8,
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
                      enabled: true,
                      maxLines: null,
                      minLines: 1,
                      scrollPhysics: const BouncingScrollPhysics(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: NordColors.nord5,
                      ),
                      decoration: InputDecoration(
                        hintText: isBusy ? '이미지 전송 중...' : 'Type a message...',
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
              if (isBusy)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: NordColors.nord8,
                      ),
                    ),
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
