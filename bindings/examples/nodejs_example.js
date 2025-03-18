const path = require('path');
const obiwan = require('../generated/node/obiwan');

async function main() {
    console.log("ObiWAN Gemini Client Example in Node.js");
    console.log("=====================================\n");

    // Create a new Gemini client with default settings
    const client = new obiwan.ObiwanClient(5, "", "");
    
    // Make a request to a Gemini server
    const url = "gemini://gemini.circumlunar.space/";
    console.log(`Sending request to: ${url}`);
    
    const response = client.request(url);
    
    // Get the status code and meta information
    const status = response.status;
    const meta = response.meta;
    
    console.log("\nResponse received:");
    console.log(`Status: ${status}`);
    console.log(`Meta: ${meta}`);
    
    // Only try to read the body if the status is 20 (Success)
    if (status === 20) {
        console.log("\nFetching body content...");
        const body = response.body();
        console.log("\n--- CONTENT ---");
        console.log(body);
        console.log("--- END OF CONTENT ---");
    } else {
        console.log("\nNot fetching body as status is not 20 (Success)");
    }
    
    // Clean up
    client.close();
    console.log("\nConnection closed");
}

main().catch(console.error);