const { example } = require('../src/example');

describe('example', () => {
  test('returns greeting', () => {
    expect(example()).toBe("Hello, World!");
  });
});
