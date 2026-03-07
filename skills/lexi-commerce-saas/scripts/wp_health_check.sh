#!/usr/bin/env bash
set -euo pipefail

# Basic health checks for lexi-api endpoints.
# Usage:
#   WP_BASE_URL="https://example.com" API_TOKEN="..." ./wp_health_check.sh

if [[ -z "${WP_BASE_URL:-}" ]]; then
  echo "WP_BASE_URL is required"
  exit 1
fi

AUTH_HEADER=()
if [[ -n "${API_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer ${API_TOKEN}")
fi

check_endpoint() {
  local name="$1"
  local url="$2"
  echo "Checking ${name} -> ${url}"
  local response
  response=$(curl -sS -L "${AUTH_HEADER[@]}" -H "Accept: application/json" "$url")
  if echo "$response" | grep -q '"ok"'; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}"
    echo "$response"
    return 1
  fi
}

check_endpoint "health" "${WP_BASE_URL}/wp-json/lexi/v1/health"
check_endpoint "app-config" "${WP_BASE_URL}/wp-json/lexi/v1/app-config"
check_endpoint "order-tracking-sample" "${WP_BASE_URL}/wp-json/lexi/v1/orders/track?order_id=sample"

echo "All basic checks completed."

