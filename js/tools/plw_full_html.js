import { chromium } from 'playwright';

async function extractFullHtml() {
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

    // Extract the full HTML inside the selector
    const html = await page.locator(selector).evaluate(el => el.outerHTML);

    console.log(html);

  } catch (error) {
    console.error('Error during processing:', error);
  } finally {
    // close the connection without closing the actual browser process
    await browser.close();
  }
}

extractFullHtml().catch(console.error);
