/**
 * flutter_server_status - Flutter 웹 개발 서버 상태 조회
 */

export default {
  definition: {
    name: 'flutter_server_status',
    description: 'Flutter 웹 개발 서버의 현재 상태를 조회합니다.',
    inputSchema: {
      type: 'object',
      properties: {},
      required: [],
    },
  },

  async execute(workingDir, args, context) {
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
      const status = flutterManager.getServerStatus(workspaceId);

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            success: true,
            ...status,
            message: status.running
              ? `Flutter 웹 서버가 ${status.url}에서 실행 중입니다.`
              : `Flutter 웹 서버가 실행 중이 아닙니다. (상태: ${status.status})`,
          }, null, 2),
        }],
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
