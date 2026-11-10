/** @type {import('jest').Config} */
module.exports = {
  testTimeout: 30000,
  projects: [
    {
      displayName: 'unit',
      preset: 'ts-jest',
      testEnvironment: 'node',
      rootDir: '.',
      testMatch: ['<rootDir>/test/unit/**/*.test.ts'],
    },
  ],
};
