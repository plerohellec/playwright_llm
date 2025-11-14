const { chromium } = require('playwright');
const { cleanHtml, trimWhitespaces, paginateHtml } = require('../slim_html.js');

async function slimHtml() {
  const pageNumber = parseInt(process.argv[2]) || 1;

  const browser = await chromium.connectOverCDP('http://localhost:9222');
  console.debug('Connected to browser');
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

    console.log('Using existing page with URL:', page.url());

    await page.emulateMedia({ colorScheme: 'dark' });
    await page.waitForSelector('#ready', { timeout: 5000 }).catch(() => {});

    const cleanedHtml = await page.evaluate(cleanHtml);
    const finalHtml = trimWhitespaces(cleanedHtml);
    console.log('Will return page', pageNumber);
    const output = paginateHtml(finalHtml, pageNumber);

    console.log(`page url: ${page.url()}`);
    console.log(output);
  } catch (error) {
    console.error('Error during processing:', error);
    exitCode = 1;

  } finally {
    // close the connection without closing the actual browser process
    await browser.close();
  }
  return exitCode;
}

slimHtml().then(exitCode => process.exit(exitCode));