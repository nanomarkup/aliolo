/**
 * Conforming Nano Markup parser for key-value maps (starting with '..')
 */
export function parseNano(content: string): Record<string, string> {
  const result: Record<string, string> = {};
  const lines = content.split(/\r?\n/);
  let currentKey: string | null = null;
  let currentValueLines: string[] = [];
  let inMultiline = false;

  for (let line of lines) {
    const trimmed = line.trim();
    
    // Ignore comments and empty lines
    if (!trimmed || trimmed.startsWith('#')) {
      if (inMultiline) {
        currentValueLines.push('');
      }
      continue;
    }

    const leadingSpaces = line.length - line.trimStart().length;

    if (inMultiline) {
      if (leadingSpaces >= 8) {
        // Line belongs to the multiline block
        currentValueLines.push(line.substring(8));
        continue;
      } else {
        // Line ends the multiline block; save preceding block
        result[currentKey!] = currentValueLines.join('\n');
        inMultiline = false;
        currentKey = null;
        currentValueLines = [];
      }
    }

    // Skip the mapping marker '..'
    if (trimmed === '..') {
      continue;
    }

    if (leadingSpaces === 4) {
      if (trimmed.endsWith('|')) {
        currentKey = trimmed.slice(0, -1).trim();
        inMultiline = true;
        currentValueLines = [];
      } else {
        const firstSpace = trimmed.indexOf(' ');
        if (firstSpace !== -1) {
          const key = trimmed.slice(0, firstSpace).trim();
          let val = trimmed.slice(firstSpace + 1).trim();
          
          if (val.startsWith('"') && val.endsWith('"')) {
            val = val.slice(1, -1);
            // Unescape standard C-style escapes
            val = val.replace(/\\([nrt"\\])/g, (match, p1) => {
              if (p1 === 'n') return '\n';
              if (p1 === 'r') return '\r';
              if (p1 === 't') return '\t';
              if (p1 === '"') return '"';
              if (p1 === '\\') return '\\';
              return match;
            });
          }
          result[key] = val;
        } else {
          result[trimmed] = '';
        }
      }
    }
  }

  // Handle EOF block save if file ended during multiline block
  if (inMultiline && currentKey) {
    result[currentKey] = currentValueLines.join('\n');
  }

  return result;
}
