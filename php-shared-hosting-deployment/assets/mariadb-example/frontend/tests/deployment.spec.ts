import { expect, test } from '@playwright/test'

test('the deployed test page renders without browser errors', async ({ page }, testInfo) => {
  const errors: string[] = []
  page.on('pageerror', error => errors.push(error.message))
  page.on('console', message => {
    if (message.type() === 'error') errors.push(message.text())
  })

  const response = await page.goto('/', { waitUntil: 'networkidle' })
  expect(response?.status()).toBe(200)
  await expect(page.getByRole('heading', { name: 'application', exact: true })).toBeVisible()
  await expect(page.getByText('Die Testseite ist erreichbar.', { exact: true })).toBeVisible()
  if (process.env.EXPECTED_COMMIT) {
    await expect(page.locator('main')).toHaveAttribute('data-source-commit', process.env.EXPECTED_COMMIT)
  }
  expect(errors).toEqual([])
  await page.screenshot({ path: testInfo.outputPath('test-page.png'), fullPage: true })
})
