# test

Benchmark project for evaluating AI test generation tools.

## Setup

```bash
npm install
```

## Run Tests

```bash
# Run tests
npm test

# Run with coverage
npm run coverage

# Watch mode
npm test:watch
```

## View Coverage

```bash
open coverage/index.html
```

## Project Structure

```
test/
├── src/           # Source code (add your functions here)
├── tests/         # Tests (add your tests here)
├── package.json   # Dependencies and scripts
└── README.md      # This file
```

## Adding Your Code

1. Add source files to `src/`
2. Add test files to `tests/` (name them `*.test.js`)
3. Run `npm test` to verify
4. Run `npm run coverage` to see coverage

## Example

```javascript
// src/example.js
function add(a, b) {
  return a + b;
}

module.exports = { add };
```

```javascript
// tests/example.test.js
const { add } = require('../src/example');

describe('add', () => {
  test('adds two numbers', () => {
    expect(add(1, 2)).toBe(3);
  });
});
```
