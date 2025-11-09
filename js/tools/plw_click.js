import { chromium } from 'playwright';
import { addVpsbIds } from '../slim_html.js';

async function click() {
  const selector = process.argv[2];
  if (!selector) {
    console.error('Please provide a selector as a command line argument');
    process.exit(1);
  }

  const browser = await chromium.connectOverCDP('http://localhost:9222');
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

    // Check if the selector exists
    const element = await page.locator(selector);
    if (await element.count() === 0) {
      console.error(`Selector "${selector}" not found on the page`);
      await browser.close();
      process.exit(1);
    }

    // Click the selector and wait for the page to settle
    await page.click(selector, { timeout: 2000 })
    await page.waitForLoadState('networkidle');
    await page.evaluate(addVpsbIds);

    console.log(JSON.stringify({ "status_code": 200, url: page.url() }));

  } catch (error) {
    console.error(`Error during processing selector "${selector}":`, error);
  } finally {
    // close the connection without closing the actual browser process
    await browser.close();
  }
}

click().catch(console.error);