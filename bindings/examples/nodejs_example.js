const path = require("path");
const obiwan = require("../generated/node/obiwan");

async function main() {
  console.log("ObiWAN Gemini Client Example in Node.js");
  console.log("=====================================\n");

  try {
    // Create a new Gemini client with default settings
    const client = new obiwan.ObiwanClient(5, "", "");

    // Make a request to a Gemini server
    const url = "gemini://geminiprotocol.net/";
    console.log(`Sending request to: ${url}`);

    let response;
    try {
      response = client.request(url);
    } catch (error) {
      console.error(`Error making request: ${error.message}`);
      client.close();
      return 1;
    }

    // Get the status code and meta information
    const status = response.status;
    const meta = response.meta;

    console.log("\nResponse received:");
    console.log(`Status: ${status}`);
    console.log(`Meta: ${meta}`);

    // Certificate information
    console.log("\nCertificate info:");
    console.log(
      `- Has certificate: ${response.hasCertificate() ? "yes" : "no"}`,
    );
    console.log(`- Is verified: ${response.isVerified() ? "yes" : "no"}`);
    console.log(`- Is self-signed: ${response.isSelfSigned() ? "yes" : "no"}`);

    // Only try to read the body if the status is 20 (Success)
    if (status === obiwan.Status.SUCCESS) {
      console.log("\nFetching body content...");
      const body = response.body();
      if (body) {
        console.log("\n--- CONTENT ---");
        console.log(body);
        console.log("--- END OF CONTENT ---");
      } else {
        console.log("\nNo body content available");
      }
    } else {
      console.log("\nNot fetching body as status is not 20 (Success)");
    }

    // Clean up
    client.close();
    console.log("\nConnection closed");

    return 0;
  } catch (error) {
    console.error(`Unexpected error: ${error.message}`);
    return 1;
  }
}

main()
  .then((exitCode) => {
    process.exitCode = exitCode;
  })
  .catch((error) => {
    console.error(`Unhandled error: ${error.message}`);
    process.exitCode = 1;
  });
