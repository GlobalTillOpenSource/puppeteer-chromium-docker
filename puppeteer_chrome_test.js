const { launchPuppeteer } = require('crawlee');

const testPageLoading = async (browser) => {
    const page = await browser.newPage();
    await page.goto('http://www.example.com');
    const pageTitle = await page.title();
    if (pageTitle !== 'Example Domain') {
        throw new Error(`Puppeteer+Chrome test failed - returned title "${pageTitle}"" !== "Example Domain"`);
    }
};

const testPuppeteerChrome = async () => {
    console.log('Testing Puppeteer with full Chrome');
    // We need --no-sandbox, because even though the build is running on GitHub, the test is running in Docker.
    const launchOptions = { headless: true, args: [
            '--disable-gpu',
            '--disable-dev-shm-usage',
            '--disable-setuid-sandbox',
            '--no-first-run',
            '--ash-no-nudges',
            '--no-sandbox',
            '--no-zygote',
            '--deterministic-fetch',
            '--disable-features=IsolateOrigins,site-per-process',
            '--disable-site-isolation-trials',
        ] };
    const launchContext = { useChrome: true, launchOptions };

    const browser = await launchPuppeteer(launchContext);
    try {
        await testPageLoading(browser);
    } finally {
        await browser.close();
    }
};

module.exports = testPuppeteerChrome;


async function closeGracefully(signal) {
    console.log(`*^!@4=> Received signal to terminate: ${signal}`)
  
    await fastify.close()
    // await db.close() if we have a db connection in this app
    // await other things we should cleanup nicely
    process.kill(process.pid, signal);
 }
 process.once('SIGINT', closeGracefully)
 process.once('SIGTERM', closeGracefully)