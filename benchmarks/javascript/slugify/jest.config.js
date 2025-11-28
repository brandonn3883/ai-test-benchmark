module.exports = {
  testEnvironment: 'node',
  coverageDirectory: 'coverage',
  collectCoverageFrom: ['src/**/*.js', '!**/node_modules/**'],
  coverageReporters: ['text', 'html', 'json-summary', 'json'],
  testMatch: ['**/tests/**/*.test.js']
};
