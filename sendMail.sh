#!/bin/bash

# Configuration
TOKEN=$1  # Accept the token as the first argument
REPO="banjoSolomon/Bottle"  # Replace with your GitHub repo in format: owner/repo
EMAILS="ayomidebanjo02@gmail.com,ayomide68@gmail.com"  # Multiple emails separated by commas
CHECK_FILE="last_pr_check.txt"  # File to store the last seen PR ID

# Fetch the latest open pull request
latest_pr_response=$(curl -s -w "%{http_code}" -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$REPO/pulls?state=open&sort=created&direction=desc")

http_code="${latest_pr_response: -3}"
latest_pr="${latest_pr_response:0:${#latest_pr_response}-3}"

# Print the latest PR response and HTTP code for debugging
echo "Latest PR Response: $latest_pr"
echo "HTTP Status Code: $http_code"

# Check for HTTP codes other than 200
if [ "$http_code" -ne 200 ]; then
  echo "Error fetching pull requests: HTTP $http_code"
  exit 1
fi

# Check if there are no open PRs
if [[ "$latest_pr" == "[]" ]]; then
  echo "No open pull requests found in the repository: $REPO."
  exit 0  # Exit with 0 to mark the script as successful even if no PRs are found
fi

# Ensure latest_pr is a valid JSON array
if ! echo "$latest_pr" | jq -e '.[0]' >/dev/null; then
  echo "Failed to parse pull request details. Response was: $latest_pr"
  exit 0  # Exit with 0 to continue without error if parsing fails
fi

# Parse PR details
pr_id=$(echo "$latest_pr" | jq -r '.[0].id')
pr_title=$(echo "$latest_pr" | jq -r '.[0].title')
pr_author=$(echo "$latest_pr" | jq -r '.[0].user.login')
pr_url=$(echo "$latest_pr" | jq -r '.[0].html_url')
pr_body=$(echo "$latest_pr" | jq -r '.[0].body')
pr_latest_commit_url=$(echo "$latest_pr" | jq -r '.[0].commits_url')

# Fetch the latest commit message for the pull request if commits_url exists
latest_commit_message="No commits found"
if [ "$pr_latest_commit_url" != "null" ]; then
  commit_response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$pr_latest_commit_url")
  if [ $? -eq 0 ]; then
    latest_commit_message=$(echo "$commit_response" | jq -r '.[-1].commit.message')
  else
    echo "Failed to fetch commit messages."
    exit 0  # Exit with 0 to handle fetch failure gracefully
  fi
fi

# Ensure all required details are available
if [ -z "$pr_id" ] || [ -z "$pr_title" ] || [ -z "$pr_author" ]; then
  echo "Incomplete pull request details, skipping email."
  exit 0  # Exit with 0 if details are incomplete
fi

# Check if the PR ID is new
if [ ! -f "$CHECK_FILE" ] || [ "$(cat "$CHECK_FILE")" != "$pr_id" ]; then
  # Save the latest PR ID
  echo "$pr_id" > "$CHECK_FILE"

  # Prepare the email content
  subject="New Pull Request: $pr_title by $pr_author"
  message="Title: $pr_title\nAuthor: $pr_author\nURL: $pr_url\n\nBody:\n$pr_body\n\nLatest Commit Message:\n$latest_commit_message"

  # Send email to multiple recipients
  echo -e "To: $EMAILS\nSubject: $subject\n\n$message" | sendmail -t

  echo "Email sent for new PR: $pr_title by $pr_author to multiple recipients"
else
  echo "No new pull request."
fi
