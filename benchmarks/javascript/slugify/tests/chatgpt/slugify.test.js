const slugify = require('../../src/slugify');

describe('slugify function', () => {
  test('should convert a simple string to slug', () => {
    expect(slugify('Hello World')).toBe('Hello-World');
  });

  test('should replace special characters using charMap', () => {
    expect(slugify('$%&')).toBe('dollar-percent-and');
  });

  test('should replace characters according to locale', () => {
    expect(slugify('Ä Ö Ü ß', { locale: 'de' })).toBe('AE-OE-UE-ss');
  });

  test('should use custom replacement character', () => {
    expect(slugify('Hello World!', { replacement: '_' })).toBe('Hello_World_');
  });

  test('should trim spaces by default', () => {
    expect(slugify('  Hello World  ')).toBe('Hello-World');
  });

  test('should not trim if trim is false', () => {
    expect(slugify('  Hello World  ', { trim: false })).toBe('--Hello-World--');
  });

  test('should lowercase string if lower is true', () => {
    expect(slugify('Hello World', { lower: true })).toBe('hello-world');
  });

  test('should remove disallowed characters when strict is true', () => {
    expect(slugify('Hello@World!', { strict: true })).toBe('HelloWorld');
  });

  test('should handle empty string', () => {
    expect(slugify('')).toBe('');
  });

  test('should throw error if input is not a string', () => {
    expect(() => slugify(null)).toThrow('slugify: string argument expected');
    expect(() => slugify(undefined)).toThrow('slugify: string argument expected');
    expect(() => slugify(123)).toThrow('slugify: string argument expected');
    expect(() => slugify({})).toThrow('slugify: string argument expected');
  });

  test('should handle string with multiple consecutive spaces', () => {
    expect(slugify('Hello   World')).toBe('Hello-World');
  });

  test('should respect custom remove regex', () => {
    expect(slugify('Hello@World!', { remove: /[!@]+/g })).toBe('Hello-World');
  });

  test('should not replace character if replacement matches char', () => {
    expect(slugify('Hello-World', { replacement: '-' })).toBe('Hello-World');
  });
});

describe('slugify.extend function', () => {
  afterEach(() => {
    // reset charMap extension to avoid side effects
    slugify.extend({ test: undefined });
  });

  test('should add custom character mapping', () => {
    slugify.extend({ '©': 'copyright' });
    expect(slugify('©')).toBe('copyright');
  });

  test('should override existing character mapping', () => {
    slugify.extend({ '$': 'bucks' });
    expect(slugify('$')).toBe('bucks');
  });

  test('should handle multiple custom mappings', () => {
    slugify.extend({ '#': 'hash', '@': 'at' });
    expect(slugify('#@')).toBe('hash-at');
  });
});

describe('edge cases', () => {
  test('should handle string with only spaces', () => {
    expect(slugify('     ')).toBe('');
    expect(slugify('     ', { trim: false })).toBe('-----');
  });

  test('should handle string with only special characters', () => {
    expect(slugify('$$$')).toBe('dollar-dollar-dollar');
  });

  test('should handle empty options object', () => {
    expect(slugify('Hello World', {})).toBe('Hello-World');
  });

  test('should handle options as string for replacement', () => {
    expect(slugify('Hello World', '_')).toBe('Hello_World');
  });
});
