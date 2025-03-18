#!/usr/bin/env python3
import sys
import os
import pathlib

# Add the generated directory to Python path
project_root = pathlib.Path(__file__).parents[2]  # Go up two directories to project root
sys.path.append(str(project_root / "bindings" / "generated"))

# Import the ObiWAN bindings
from python.obiwan import ObiwanClient, Status, checkError, takeError

def main():
    print("ObiWAN Gemini Client Example in Python")
    print("=====================================\n")

    try:
        # Create a new Gemini client with default settings
        client = ObiwanClient(5, "", "")

        # Check for errors
        if checkError():
            print(f"Error creating client: {takeError()}")
            return 1

        # Make a request to a Gemini server
        url = "gemini://geminiprotocol.net/"
        print(f"Sending request to: {url}")

        response = client.request(url)

        # Check for errors
        if checkError():
            print(f"Error making request: {takeError()}")
            client.close()
            return 1

        # Get the status code and meta information
        print("\nResponse received:")
        print(f"Status: {response.status}")
        print(f"Meta: {response.meta}")

        # Certificate information
        print("\nCertificate info:")
        print(f"- Has certificate: {'yes' if response.hasCertificate() else 'no'}")
        print(f"- Is verified: {'yes' if response.isVerified() else 'no'}")
        print(f"- Is self-signed: {'yes' if response.isSelfSigned() else 'no'}")

        # Only try to read the body if the status is 20 (Success)
        if response.status == Status.SUCCESS:
            body = response.body()
            if body:
                print("\nResponse body:")
                print("\n--- CONTENT ---")
                print(body)
                print("--- END OF CONTENT ---")
            else:
                print("\nNo body content available")
        else:
            print("\nNot showing body as status is not 20 (Success)")

        # Clean up
        client.close()
        print("\nConnection closed")

    except Exception as e:
        print(f"Error: {e}")
        return 1

    return 0

if __name__ == "__main__":
    sys.exit(main())
