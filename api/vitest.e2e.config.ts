import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    pool: 'forks', // Use standard Node.js pool instead of Cloudflare Workers pool
    include: ['test/e2e/**/*.spec.ts'],
    fileParallelism: false,
  },
});
