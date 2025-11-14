const { chromium } = require('playwright');
const { addVpsbIds } = require('../slim_html.js');

async function click() {
  const selector = process.argv[2];
  if (!selector) {
    console.error('Please provide a selector as a command line argument');
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

    // Check if the selector exists
    const element = await page.locator(selector);
    if (await element.count() === 0) {
      console.error(`Selector "${selector}" not found on the page`);
      exitCode = 1;
    } else if (!(await element.isVisible())) {
      console.error(`Selector "${selector}" is not visible on the page`);
      exitCode = 1;
    } else if (!(await element.isEnabled())) {
      console.error(`Selector "${selector}" is not enabled on the page`);
      exitCode = 1;
    } else {
      const innerText = await element.innerText();
      const truncatedText = innerText.substring(0, 100);
      console.log(`Selector inner text: ${truncatedText}`);

      // Click the selector and wait for the page to settle
      await page.click(selector, { timeout: 2000 })
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
          console.warn('Timed out waiting for networkidle, but document.readyState is complete — continuing.');
        } else {
          throw err;
        }
      }
      await page.evaluate(addVpsbIds);

      console.log(JSON.stringify({ "status_code": 200, url: page.url() }));
    }

  } catch (error) {
    console.error(`Error during processing selector "${selector}":`, error);
    exitCode = 1;
  } finally {
    // close the connection without closing the actual browser process
    await browser.close();
  }
  return exitCode;
}

click().then(exitCode => process.exit(exitCode));