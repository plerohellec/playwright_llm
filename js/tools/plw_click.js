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

    // Check if the selector exists and find the first visible and enabled element
    const elements = await page.locator(selector).all();
    if (elements.length === 0) {
      console.error(`Selector "${selector}" not found on the page`);
      exitCode = 1;
    } else {
      let targetElement = null;
      for (const el of elements) {
        if (await el.isVisible() && await el.isEnabled()) {
          targetElement = el;
          break;
        }
      }
      if (!targetElement) {
        console.error(`No visible and enabled element found for selector "${selector}"`);
        exitCode = 1;
      } else {
        const innerText = await targetElement.innerText();
        const truncatedText = innerText.substring(0, 100);
        const tagName = await targetElement.evaluate(el => el.tagName.toLowerCase());
        console.log(`PLWLLM_LOG: Selector type: ${tagName}, inner text: "${truncatedText}"`);

        // Click the target element and wait for the page to settle
        await targetElement.click({ timeout: 4000 });
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
    console.error(`Error during processing selector "${selector}":`, error);
    exitCode = 1;
  } finally {
    await browser.close();
  }
  return exitCode;
}

click().then(exitCode => process.exit(exitCode));