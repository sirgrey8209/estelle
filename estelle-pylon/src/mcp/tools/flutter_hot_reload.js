/**
 * flutter_hot_reload - Flutter Hot Reload / Hot Restart 트리거
 */

export default {
  definition: {
    name: 'flutter_hot_reload',
    description: 'Flutter 앱에 Hot Reload를 트리거합니다. 코드 변경 후 호출하세요.',
    inputSchema: {
      type: 'object',
      properties: {
        restart: {
          type: 'boolean',
          description: 'true면 Hot Restart (앱 상태 초기화), false면 Hot Reload (기본)',
        },
      },
      required: [],
    },
  },

  async execute(workingDir, args, context) {
    const { restart = false } = args;
    const { workspaceId, flutterManager } = context;

    if (!flutterManager) {
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            success: false,
            error: 'FlutterDevManager not available',
          }, null, 2),
        }],
        isError: true,
      };
    }

    try {
      const result = restart
        ? flutterManager.hotRestart(workspaceId)
        : flutterManager.hotReload(workspaceId);

      const action = restart ? 'Hot Restart' : 'Hot Reload';

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            success: result.success,
            action,
            message: result.success
              ? `${action} 트리거됨. 브라우저에서 변경사항을 확인하세요.`
              : `${action} 실패: ${result.error}`,
          }, null, 2),
        }],
        isError: !result.success,
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            success: false,
            error: error.message,
          }, null, 2),
        }],
        isError: true,
      };
    }
  },
};
