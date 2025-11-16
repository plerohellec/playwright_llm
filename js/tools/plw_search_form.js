const { chromium } = require('playwright');
const { addVpsbIds } = require('../slim_html.js');

async function searchForm() {
  const formId = process.argv[2];
  const searchTerm = process.argv[3];
  if (!formId || !searchTerm) {
    console.error('Please provide form id and search term as command line arguments');
    process.exit(1);
  }

  const browser = await chromium.connectOverCDP('http://localhost:9222');
  let exitCode = 0;
  try {
    const contexts = browser.contexts();
    if (contexts.length === 0) {
      throw new Error('No contexts found. Make sure launcher.js is running.');
    }
    const context = contexts[0];

    const pages = context.pages();
    if (pages.length === 0) {
      throw new Error('No pages found in context. Make sure launcher.js has opened a page.');
    }
    const page = pages[0];
    await page.emulateMedia({ colorScheme: 'dark' });

    // Check if the form exists
    const form = page.locator(`#${formId}`);
    if (!(await form.count())) {
      console.error(`Form with id "${formId}" not found on the page`);
      exitCode = 1;
    } else {
      // Find the input inside the form
      const input = form.locator('input[type="text"], input[type="search"], input:not([type])').first();
      if (!(await input.count())) {
        console.error(`No suitable input found in form "${formId}"`);
        exitCode = 1;
      } else {
        // Fill the input
        await input.fill(searchTerm);
        console.log(`PLWLLM_LOG: Filled input with "${searchTerm}"`);

        // Submit the form by clicking the submit button or submitting the form
        const submitButton = form.locator('input[type="submit"], button[type="submit"]').first();
        if (await submitButton.count()) {
          await submitButton.click({ timeout: 4000 });
        } else {
          await form.evaluate(form => form.submit());
        }

        // Wait for the page to settle
        try {
          await page.waitForLoadState('networkidle', { timeout: 5000 });
        } catch (err) {
          if (err && err.name === 'TimeoutError') {
            const readyState = await page.evaluate(() => document.readyState);
            if (readyState !== 'complete') {
              throw new Error(
                `Timed out waiting for networkidle (5s); document.readyState='${readyState}'`
              );
            }
            console.warn('PLWLLM_LOG: Timed out waiting for networkidle, but document.readyState is complete — continuing.');
          } else {
            throw err;
          }
        }
        await page.evaluate(addVpsbIds);

        console.log(JSON.stringify({ "status_code": 200, url: page.url() }));
      }
    }
  } catch (error) {
    console.error(`Error during searching in form "${formId}":`, error);
    exitCode = 1;
  } finally {
    await browser.close();
  }
  return exitCode;
}

searchForm().then(exitCode => process.exit(exitCode));