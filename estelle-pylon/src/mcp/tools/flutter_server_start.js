/**
 * flutter_server_start - Flutter 웹 개발 서버 시작
 */

export default {
  definition: {
    name: 'flutter_server_start',
    description: 'Flutter 웹 개발 서버를 시작합니다. Hot Reload를 위해 포그라운드로 실행됩니다.',
    inputSchema: {
      type: 'object',
      properties: {
        port: {
          type: 'number',
          description: '웹 서버 포트 (기본: 8080)',
        },
      },
      required: [],
    },
  },

  async execute(workingDir, args, context) {
    const { port = 8080 } = args;
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
      // estelle-app 경로 (workingDir가 estelle 루트라고 가정)
      const appDir = workingDir.includes('estelle-app')
        ? workingDir
        : `${workingDir}\\estelle-app`;

      const result = await flutterManager.startServer(workspaceId, appDir, { port });

      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            success: result.success,
            url: result.url,
            message: result.success
              ? `Flutter 웹 서버가 시작되었습니다. ${result.url} 에서 확인하세요.`
              : `서버 시작 실패: ${result.error}`,
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
