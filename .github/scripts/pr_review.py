#!/usr/bin/env python3
"""
PR Review script — triggered by @claude mention in a PR comment.
Fetches the PR diff, sends it to Claude for review, posts the result.
Uses only Python stdlib — no external dependencies needed.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request

ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_VERSION = "2023-06-01"
MODEL = "claude-sonnet-4-6"
MAX_TOKENS = 4096
MAX_DIFF_BYTES = 80_000  # ~20k tokens, leaves room for response

SYSTEM_PROMPT = """\
You are an expert Solidity smart contract reviewer for a Foundry project. \
When reviewing a PR diff, focus on:

1. **Security vulnerabilities** — reentrancy, access control, overflow/underflow, \
front-running, oracle manipulation, unchecked external calls, signature replay
2. **Correctness** — logic errors, invariant violations, edge cases
3. **Gas optimization** — redundant storage reads, inefficient loops, \
unnecessary computation
4. **Foundry best practices** — test coverage gaps, missing forge coverage, \
CheatCodes usage, fuzz test improvements
5. **Code quality** — readability, naming, SOLID principles, NatSpec comments

Format your review as a concise PR comment:
- Use a 🔴 / 🟡 / 🔵 severity tag on each finding
- Include the specific file and line reference
- Suggest a concrete fix for each issue
- End with a summary verdict (✅ Approve / ⚠️ Changes Requested / 💬 Comment)

Keep it actionable — don't nitpick formatting that forge fmt would catch."""


def log(msg: str) -> None:
    print(f"[claude-review] {msg}", file=sys.stderr)


def github_api(path: str, method: str = "GET", body: dict | None = None) -> dict:
    """Call the GitHub REST API."""
    token = os.environ["GH_TOKEN"]
    url = f"https://api.github.com{path}"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    data = json.dumps(body).encode() if body else None
    if data:
        headers["Content-Type"] = "application/json"

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err_body = e.read().decode(errors="replace")
        err_msg = f"GitHub API error {e.code}: {err_body}"
        log(err_msg)
        if "Resource not accessible by integration" in err_body:
            raise RuntimeError(
                "GitHub token lacks write permissions. "
                "Create a fine-grained PAT with read/write issues & pull-requests "
                "scopes for this repo, then add it as secret GH_PAT:\n"
                "  gh secret set GH_PAT --repo BLOKCapital/blokc-v1-core -b 'github_pat_...'"
            ) from e
        raise RuntimeError(err_msg) from e


def claude_review(diff: str) -> str:
    """Send the diff to Claude and return the review text."""
    api_key = os.environ["CLAUDE_API_KEY"]
    headers = {
        "x-api-key": api_key,
        "anthropic-version": ANTHROPIC_VERSION,
        "content-type": "application/json",
    }
    body = {
        "model": MODEL,
        "max_tokens": MAX_TOKENS,
        "system": SYSTEM_PROMPT,
        "messages": [
            {
                "role": "user",
                "content": f"Please review this PR diff:\n\n```diff\n{diff}\n```",
            }
        ],
    }

    req = urllib.request.Request(
        ANTHROPIC_API_URL,
        data=json.dumps(body).encode(),
        headers=headers,
    )
    try:
        with urllib.request.urlopen(req) as resp:
            result = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err_body = e.read().decode(errors="replace")
        err_msg = f"Claude API error {e.code}: {err_body}"
        log(err_msg)
        # Detect common issues
        if "credit balance is too low" in err_body:
            raise RuntimeError(
                "Claude API credits are exhausted. "
                "Top up at https://console.anthropic.com/settings/billing"
            ) from e
        if "invalid x-api-key" in err_body.lower():
            raise RuntimeError(
                "Invalid CLAUDE_API_KEY. Check the secret in repo Settings → Secrets."
            ) from e
        raise RuntimeError(err_msg) from e

    # Extract text from the first content block
    content = result.get("content", [])
    for block in content:
        if block.get("type") == "text":
            return block["text"]
    return "Claude returned no text response."


def get_pr_diff(pr_number: int) -> str:
    """Fetch the unified diff for a PR."""
    # Use the media type for diff format
    token = os.environ["GH_TOKEN"]
    url = (
        f"https://api.github.com/repos/{os.environ['GITHUB_REPOSITORY']}"
        f"/pulls/{pr_number}"
    )
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github.diff",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req) as resp:
        diff = resp.read().decode()
    return diff


def post_review(pr_number: int, body: str) -> None:
    """Post a proper GitHub Pull Request Review (not a plain comment)."""
    # Determine review event based on content
    body_lower = body.lower()
    if any(phrase in body_lower for phrase in ["critical", "🔴 critical", "changes requested"]):
        event = "REQUEST_CHANGES"
    elif any(phrase in body_lower for phrase in ["approved", "✅ approve", "lgtm"]):
        event = "APPROVE"
    else:
        event = "COMMENT"

    payload: dict = {
        "body": body,
        "event": event,
    }
    log(f"Posting GitHub review (event={event}) on PR #{pr_number}...")
    github_api(
        f"/repos/{os.environ['GITHUB_REPOSITORY']}/pulls/{pr_number}/reviews",
        method="POST",
        body=payload,
    )
    log(f"Review posted successfully (event={event}).")


def add_reaction(comment_id: int, reaction: str = "eyes") -> None:
    """Add a reaction to acknowledge the trigger comment."""
    github_api(
        f"/repos/{os.environ['GITHUB_REPOSITORY']}/issues/comments/{comment_id}/reactions",
        method="POST",
        body={"content": reaction},
    )


def extract_focus(comment_body: str) -> str | None:
    """If the user specified a focus area, extract it."""
    match = re.search(r"@claude\s+focus:\s*(.+)", comment_body, re.IGNORECASE)
    return match.group(1).strip() if match else None


def main():
    log("Starting PR review...")

    # Parse event payload from environment
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    if not event_path:
        log("ERROR: GITHUB_EVENT_PATH not set")
        sys.exit(1)

    with open(event_path) as f:
        event = json.load(f)

    comment = event.get("comment", {})
    issue = event.get("issue", {})
    pr_number = issue.get("number")
    comment_id = comment.get("id")
    comment_body = comment.get("body", "")
    comment_user = comment.get("user", {}).get("login", "unknown")

    if not pr_number:
        log("ERROR: Could not determine PR number")
        sys.exit(1)

    log(f"Triggered by @{comment_user} on PR #{pr_number}")

    # Acknowledge with a reaction
    if comment_id:
        try:
            add_reaction(comment_id, "eyes")
        except Exception as e:
            log(f"Warning: Could not add reaction: {e}")

    # Optional focus hint
    focus = extract_focus(comment_body)
    focus_note = f"\n\n_(Reviewer focused on: **{focus}**)_" if focus else ""

    # Get the PR diff
    log("Fetching PR diff...")
    diff = get_pr_diff(pr_number)

    if not diff.strip():
        post_review(
            pr_number,
            f"🤖 @{comment_user} — this PR has no diff to review (maybe it's already merged?).",
        )
        return

    # Truncate if needed
    diff_bytes = diff.encode()
    if len(diff_bytes) > MAX_DIFF_BYTES:
        diff = diff_bytes[:MAX_DIFF_BYTES].decode(errors="replace")
        log(f"Diff truncated to {MAX_DIFF_BYTES} bytes")

    log(f"Diff size: {len(diff_bytes)} bytes. Sending to Claude...")

    # Call Claude
    try:
        review = claude_review(diff)
    except Exception as e:
        log(f"Claude API call failed: {e}")
        post_review(
            pr_number,
            f"🤖 @{comment_user} — sorry, the Claude API call failed. "
            f"Check the workflow logs for details.\n\n```\n{e}\n```",
        )
        sys.exit(1)

    # Clean up the review — strip markdown code fences the model might wrap in
    review = review.strip()
    if review.startswith("```"):
        review = re.sub(r"^```\w*\n?", "", review)
        review = re.sub(r"\n```$", "", review)

    # Post the review
    header = f"## 🤖 Claude Code Review{focus_note}\n\n"
    divider = "\n\n---\n\n*Requested by @{user} — [Claude Code](https://claude.com/claude-code)*".format(
        user=comment_user
    )
    full_comment = header + review + divider
    post_review(pr_number, full_comment)


if __name__ == "__main__":
    main()
