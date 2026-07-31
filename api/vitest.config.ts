import { defineConfig } from 'vitest/config';
import { cloudflareTest } from '@cloudflare/vitest-pool-workers';

export default defineConfig({
  plugins: [
    cloudflareTest({
      // Tests use isolated bindings and do not require a prebuilt Flutter asset directory.
      wrangler: { configPath: 'wrangler.test.jsonc' },
    }),
  ],
  test: {
    pool: '@cloudflare/vitest-pool-workers',
    setupFiles: ['./test/setup.ts'],
    fileParallelism: false,
  },
});
