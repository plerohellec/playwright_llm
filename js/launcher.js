const { chromium } = require('playwright');

(async () => {
  // Launch browser normally (not as server) to keep state persistent
  const browser = await chromium.launch({
    headless: true,
    args: ['--remote-debugging-port=9222']
  });

  const context = await browser.newContext({
    userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36",
    colorScheme: 'dark'
  });
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
