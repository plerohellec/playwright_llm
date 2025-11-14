const { chromium } = require('playwright');

const parseHeadless = () => {
  const envValue = process.env.PLAYWRIGHT_LLM_HEADLESS;
  if (!envValue) {
    return true;
  }

  const normalized = envValue.trim().toLowerCase();
  return !['false', '0', 'no', 'off'].includes(normalized);
};

(async () => {
  // Launch browser normally (not as server) to keep state persistent
  const headless = parseHeadless();
  const userAgent = process.env.PLAYWRIGHT_LLM_USER_AGENT;

  const browser = await chromium.launch({
    headless,
    args: ['--remote-debugging-port=9222']
  });

  const contextOptions = {
    colorScheme: 'dark'
  };
  if (userAgent) {
    contextOptions.userAgent = userAgent;
  }
  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();

  console.log('{ "status_code": 200 }');

  // keep the process alive indefinitely
  // Handle termination signals to close browser gracefully
  process.on('SIGINT', async () => {
    console.log('Received SIGINT, closing browser...');
    await browser.close();
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    console.log('Received SIGTERM, closing browser...');
    await browser.close();
    process.exit(0);
  });

  // Keep the process alive indefinitely
  await new Promise(() => {});
})();
