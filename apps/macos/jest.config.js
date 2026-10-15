module.exports = {
  preset: 'react-native-macos',
  moduleNameMapper: {
    '^react-native$': 'react-native-macos',
    '^react-native/(.*)$': '<rootDir>/../../node_modules/react-native-macos/$1',
  },
  transformIgnorePatterns: [
    'node_modules/(?!((jest-)?react-native(-macos)?|@react-native(-community)?)/)',
  ],
};
