#!/usr/bin/env bash

IP=$(terraform output -raw socksbox_ip)

echo "Running socks tunnel in background..."
ssh -D 1337 -q -C -N -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ec2-user@${IP} &

# Capture the PID of the last background process
pid=$!

# Save the PID to a file
echo $pid > pidfile.txt

echo "PID saved to pidfile.txt"

echo "Socks tunnel created. point your browser's socks proxy to localhost:1337"

echo "The tunnel will be killed when you run \"terraform destroy\""
