const path = require('path');

module.exports = {
  reactNativePath: path.dirname(
    require.resolve('react-native-macos/package.json'),
  ),
};
