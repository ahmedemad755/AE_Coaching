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
    {
      displayName: 'emulator',
      preset: 'ts-jest',
      testEnvironment: 'node',
      rootDir: '.',
      testMatch: ['<rootDir>/test/emulator/**/*.test.ts'],
    },
    {
      displayName: 'e2e',
      preset: 'ts-jest',
      testEnvironment: 'node',
      rootDir: '.',
      testMatch: ['<rootDir>/test/e2e/**/*.test.ts'],
    },
  ],
};
