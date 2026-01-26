/**
 * flutter_server_stop - Flutter 웹 개발 서버 중지
 */

export default {
  definition: {
    name: 'flutter_server_stop',
    description: 'Flutter 웹 개발 서버를 중지합니다.',
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
      const result = flutterManager.stopServer(workspaceId);

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            success: result.success,
            message: result.success
              ? 'Flutter 웹 서버가 중지되었습니다.'
              : `서버 중지 실패: ${result.error}`,
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
