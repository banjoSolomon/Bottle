#!/bin/bash

# Configuration
TOKEN=$1
SMTP_USER=$2
SMTP_PASS=$3
REPO="banjoSolomon/Bottle"
EMAILS="ayomidebanjo02@gmail.com,ayomide68@gmail.com"
CHECK_FILE="last_pr_check.txt"

# Fetch the latest open pull request
latest_pr_response=$(curl -s -H "Authorization: token $TOKEN" "https://api.github.com/repos/$REPO/pulls?state=open&sort=created&direction=desc")
latest_pr=$(echo "$latest_pr_response" | jq -r '.[0]')
pr_id=$(echo "$latest_pr" | jq -r '.id')

# Check if PR ID is new
if [ ! -f "$CHECK_FILE" ] || [ "$(cat "$CHECK_FILE")" != "$pr_id" ]; then
  echo "$pr_id" > "$CHECK_FILE"

  # Extract PR details
  pr_title=$(echo "$latest_pr" | jq -r '.title')
  pr_author=$(echo "$latest_pr" | jq -r '.user.login')
  pr_url=$(echo "$latest_pr" | jq -r '.html_url')
  pr_body=$(echo "$latest_pr" | jq -r '.body')

  # Email content
  subject="New Pull Request: $pr_title by $pr_author"
  message="Title: $pr_title\nAuthor: $pr_author\nURL: $pr_url\n\nBody:\n$pr_body"

  # Send email via SMTP
  echo -e "Subject: $subject\nTo: $EMAILS\n\n$message" | \
  sendmail -S smtp.gmail.com:587 -au"$SMTP_USER" -ap"$SMTP_PASS"

  echo "Email sent for new PR: $pr_title by $pr_author."
else
  echo "No new pull request."
fi
