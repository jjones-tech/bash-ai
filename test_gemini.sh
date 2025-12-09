#!/bin/bash

GEMINI_API_KEY=$(security find-generic-password -a "$USER" -s "gemini-api-key" -w 2>/dev/null)
MODEL="gemini-1.5-flash"

payload='{"contents":[{"parts":[{"text":"Say hello"}]}]}'

echo "Sending: $payload"

response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
  -H 'Content-Type: application/json' \
  -d "$payload")

echo "Response: $response"
