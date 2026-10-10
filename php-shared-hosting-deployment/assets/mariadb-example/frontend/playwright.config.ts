import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './tests',
  workers: 1,
  use: {
    baseURL: process.env.DEPLOYMENT_URL ?? 'http://127.0.0.1:4173',
    browserName: 'chromium',
    launchOptions: process.env.CHROMIUM_EXECUTABLE
      ? { executablePath: process.env.CHROMIUM_EXECUTABLE }
      : {},
  },
  webServer: process.env.DEPLOYMENT_URL ? undefined : {
    command: 'npm run preview -- --host 127.0.0.1 --port 4173',
    url: 'http://127.0.0.1:4173/app/',
  },
})
