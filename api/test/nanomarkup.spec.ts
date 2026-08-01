import { describe, expect, it } from 'vitest';
import { parseNano } from '../src/utils/nanomarkup';

describe('Nano Markup Parser', () => {
  it('should parse simple key value maps', () => {
    const content = `..
    key1 value1
    key2 "value with spaces"
    key3 ""
    key4 val_4`;
    
    const parsed = parseNano(content);
    expect(parsed).toEqual({
      key1: 'value1',
      key2: 'value with spaces',
      key3: '',
      key4: 'val_4',
    });
  });

  it('should parse quoted strings with escaped chars', () => {
    const content = `..
    title "Hello \\"World\\""
    newline "Line 1\\nLine 2"
    escaped "\\\\path\\\\to\\\\file"`;

    const parsed = parseNano(content);
    expect(parsed).toEqual({
      title: 'Hello "World"',
      newline: 'Line 1\nLine 2',
      escaped: '\\path\\to\\file',
    });
  });

  it('should parse multiline blocks with 8 space indentation', () => {
    const content = `..
    body|
        This is a multiline
        block of text.
        
        It preserves newlines!
    simple val`;

    const parsed = parseNano(content);
    expect(parsed).toEqual({
      body: 'This is a multiline\nblock of text.\n\nIt preserves newlines!',
      simple: 'val',
    });
  });

  it('should ignore comments and empty lines', () => {
    const content = `..
    # This is a comment
    
    key1 value1
    
    # Another comment
    key2 value2`;

    const parsed = parseNano(content);
    expect(parsed).toEqual({
      key1: 'value1',
      key2: 'value2',
    });
  });
});
