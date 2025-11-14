const { chromium } = require('playwright');
const { addVpsbIds } = require('../slim_html.js');

async function navigate() {
  const url = process.argv[2];

  if (!url) {
    console.error('Usage: node plw_navigate.js <url>');
    process.exit(1);
  }

  const browser = await chromium.connectOverCDP('http://localhost:9222');
  console.log('Connected to browser');
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

    console.log('Navigating to:', url);
    const response = await page.goto(url, { waitUntil: 'load' });
    await page.waitForLoadState('networkidle');

    console.log('Page loaded');

    await page.evaluate(addVpsbIds);

    console.log(JSON.stringify({ "status_code": response.status() }));
  } catch (error) {
    console.error('Error during processing:', error);
    exitCode = 1;
  } finally {
    // close the connection without closing the actual browser process
    await browser.close();
  }
  return exitCode;
}

navigate().then(exitCode => process.exit(exitCode));