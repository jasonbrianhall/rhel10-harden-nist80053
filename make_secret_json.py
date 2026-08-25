#!/usr/bin/env python
import json
import sys

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <path-to-private-key> [output-json-path]", file=sys.stderr)
        sys.exit(1)

    key_path = sys.argv[1]
    out_path = sys.argv[2] if len(sys.argv) > 2 else "/tmp/secret.json"

    with open(key_path) as f:
        key_data = f.read()

    with open(out_path, "w") as f:
        json.dump({"Value": key_data}, f)

    print(f"Wrote {out_path}")

if __name__ == "__main__":
    main()
