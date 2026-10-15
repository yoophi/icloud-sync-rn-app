const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const workspaceRoot = path.resolve(__dirname, '../..');
const reactNativeRoot = path.dirname(
  require.resolve('react-native/package.json'),
);
const config = {
  watchFolders: [workspaceRoot],
  serializer: {
    getModulesRunBeforeMainModule: () => [
      path.join(reactNativeRoot, 'src/setup-env.js'),
    ],
  },
  resolver: {
    nodeModulesPaths: [path.join(workspaceRoot, 'node_modules')],
    resolveRequest(context, moduleName, platform) {
      if (
        moduleName === 'react-native' ||
        moduleName.startsWith('react-native/')
      ) {
        moduleName = reactNativeRoot + moduleName.slice('react-native'.length);
      }
      return context.resolveRequest(context, moduleName, platform);
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
