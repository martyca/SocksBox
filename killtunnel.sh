#!/usr/bin/env bash

echo "Killing socks tunnel..."


# Get the pid stored in the pidfile
pid=$(cat pidfile.txt)

# Kill the tunnel
kill ${pid}

# Remove pidfile
rm pidfile.txt

echo "Tunnel killed..."
