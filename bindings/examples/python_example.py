#!/usr/bin/env python3
import sys
import os
import pathlib

# Add the generated directory to Python path
project_root = pathlib.Path(__file__).parents[2]  # Go up two directories to project root
sys.path.append(str(project_root / "bindings" / "generated"))

# Import the ObiWAN bindings
from python.obiwan import ObiwanClient, Status

def main():
    print("ObiWAN Gemini Client Example in Python")
    print("=====================================\n")

    try:
        # Create a new Gemini client with default settings
        client = ObiwanClient(5, "", "")
        
        # Make a request to a Gemini server
        url = "gemini://gemini.circumlunar.space/"
        print(f"Sending request to: {url}")
        
        response = client.request(url)
        
        # Get the status code and meta information
        print("\nResponse received:")
        print(f"Status: {response.status}")
        print(f"Meta: {response.meta}")
        
        # Only try to read the body if the status is 20 (Success)
        if response.status == Status.SUCCESS:
            print("\nResponse body:")
            print("\n--- CONTENT ---")
            print(response.body)
            print("--- END OF CONTENT ---")
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