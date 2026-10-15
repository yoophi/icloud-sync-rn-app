const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');
const path = require('path');

const workspaceRoot = path.resolve(__dirname, '../..');
const macosRoot = path.dirname(
  require.resolve('react-native-macos/package.json'),
);

module.exports = mergeConfig(getDefaultConfig(__dirname), {
  watchFolders: [workspaceRoot],
  serializer: {
    getModulesRunBeforeMainModule: () => [
      path.join(macosRoot, 'Libraries/Core/InitializeCore.js'),
    ],
  },
  resolver: {
    platforms: ['macos', 'native'],
    nodeModulesPaths: [
      path.join(__dirname, 'node_modules'),
      path.join(workspaceRoot, 'node_modules'),
    ],
    // Redirect both public imports and RN internal imports to the AppKit fork.
    resolveRequest(context, moduleName, platform) {
      if (
        moduleName === 'react-native' ||
        moduleName.startsWith('react-native/')
      ) {
        moduleName = macosRoot + moduleName.slice('react-native'.length);
      }
      return context.resolveRequest(context, moduleName, platform);
    },
  },
});
