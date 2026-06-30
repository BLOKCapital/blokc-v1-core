#!/usr/bin/env python3
"""
PR Review script — triggered by @claude mention in a PR comment.
Fetches the PR diff, sends it to Claude, and posts findings as inline
review comments on the specific lines (Copilot-style).

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
MAX_TOKENS = 8192
MAX_DIFF_BYTES = 80_000

SYSTEM_PROMPT = """\
You are an expert Solidity smart contract reviewer for a Foundry project.

When reviewing a PR diff, focus on:
1. **Security** — reentrancy, access control, overflow, front-running, oracle manipulation
2. **Correctness** — logic errors, invariant violations, edge cases
3. **Gas** — redundant storage reads, inefficient loops
4. **Best practices** — test coverage, NatSpec, naming

You MUST respond with a JSON object containing:
{
  "verdict": "REQUEST_CHANGES" | "APPROVE" | "COMMENT",
  "summary": "2-3 sentence high-level summary of the PR changes",
  "findings": [
    {
      "file": "src/Foo.sol",
      "line": 42,
      "severity": "critical" | "medium" | "info",
      "body": "What's wrong and how to fix it. Use backticks for code."
    }
  ]
}

- Use "critical" for vulnerabilities, broken logic, fund-loss risks
- Use "medium" for code quality, missing checks, gas improvements
- Use "info" for style, naming, documentation nits
- Include the exact file path as shown in the diff
- Line numbers MUST match the NEW (right-side) line numbers in the unified diff (lines starting with + or context lines)
- Only include findings that are worth a developer's time
- Maximum 12 findings total
- If there are no meaningful findings, return an empty findings array

ONLY output the JSON object. No markdown, no code fences, no preamble."""

USER_PROMPT = """Review this PR diff. Focus on logic errors, security issues, and correctness.
Return ONLY the JSON object as specified.

```diff
{diff}
```"""


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


def claude_review(diff: str) -> dict:
    """Send the diff to Claude and return parsed review JSON."""
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
            {"role": "user", "content": USER_PROMPT.format(diff=diff)},
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
        if "credit balance is too low" in err_body:
            raise RuntimeError(
                "Claude API credits exhausted. "
                "Top up at https://console.anthropic.com/settings/billing"
            ) from e
        if "invalid x-api-key" in err_body.lower():
            raise RuntimeError(
                "Invalid CLAUDE_API_KEY. Check the secret in repo Settings → Secrets."
            ) from e
        raise RuntimeError(err_msg) from e

    # Extract text from response
    for block in result.get("content", []):
        if block.get("type") == "text":
            text = block["text"].strip()
            # Strip markdown code fences if present
            if text.startswith("```"):
                text = re.sub(r"^```\w*\n?", "", text)
                text = re.sub(r"\n```$", "", text)
            try:
                return json.loads(text)
            except json.JSONDecodeError:
                log(f"Failed to parse Claude response as JSON. Raw: {text[:500]}")
                raise RuntimeError("Claude response was not valid JSON")
    raise RuntimeError("Claude returned no text response.")


def get_pr_files(pr_number: int) -> list[dict]:
    """Fetch the list of files changed in the PR."""
    files = github_api(
        f"/repos/{os.environ['GITHUB_REPOSITORY']}/pulls/{pr_number}/files?per_page=100"
    )
    return files


def get_pr_diff(pr_number: int) -> str:
    """Fetch the unified diff for a PR."""
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
        return resp.read().decode()


def validate_finding(file: str, line: int, pr_files: list[dict]) -> bool:
    """Check that the file exists in the PR and the line is valid."""
    for f in pr_files:
        if f["filename"] == file:
            # We can't easily validate the exact line, but we check the file exists
            return True
    return False


def post_review(pr_number: int, summary: str, findings: list[dict], verdict: str, pr_files: list[dict]) -> None:
    """Post a GitHub PR Review with inline comments on specific lines."""
    # Filter and validate findings
    inline_comments = []
    for f in findings:
        file_path = f.get("file", "")
        line = f.get("line", 0)
        severity = f.get("severity", "info")
        body = f.get("body", "")

        if not file_path or not line or not body:
            continue
        if not validate_finding(file_path, line, pr_files):
            log(f"Skipping finding for unknown file: {file_path}")
            continue

        emoji = {"critical": "🔴", "medium": "🟡"}.get(severity, "🔵")
        inline_comments.append({
            "path": file_path,
            "line": line,
            "body": f"{emoji} **{severity}:** {body}",
        })

    if not inline_comments:
        log("No valid inline findings to post. Posting summary-only review.")
        github_api(
            f"/repos/{os.environ['GITHUB_REPOSITORY']}/pulls/{pr_number}/reviews",
            method="POST",
            body={"body": summary, "event": "COMMENT"},
        )
        return

    # Map verdict to GitHub review event
    event_map = {
        "REQUEST_CHANGES": "REQUEST_CHANGES",
        "APPROVE": "APPROVE",
        "COMMENT": "COMMENT",
    }
    event = event_map.get(verdict, "COMMENT")

    payload = {
        "body": summary,
        "event": event,
        "comments": inline_comments,
    }
    log(f"Posting review with {len(inline_comments)} inline comments (event={event})...")
    github_api(
        f"/repos/{os.environ['GITHUB_REPOSITORY']}/pulls/{pr_number}/reviews",
        method="POST",
        body=payload,
    )
    log("Review posted successfully.")


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

    # Acknowledge
    if comment_id:
        try:
            add_reaction(comment_id, "eyes")
        except Exception as e:
            log(f"Warning: Could not add reaction: {e}")

    focus = extract_focus(comment_body)
    focus_note = f"\n\n_(Focused on: **{focus}**)_" if focus else ""

    # Get PR files for validation
    log("Fetching PR files...")
    pr_files = get_pr_files(pr_number)

    # Get the diff
    log("Fetching PR diff...")
    diff = get_pr_diff(pr_number)

    if not diff.strip():
        github_api(
            f"/repos/{os.environ['GITHUB_REPOSITORY']}/pulls/{pr_number}/reviews",
            method="POST",
            body={"body": f"🤖 Nothing to review — this PR has no diff.", "event": "COMMENT"},
        )
        return

    diff_bytes = diff.encode()
    if len(diff_bytes) > MAX_DIFF_BYTES:
        diff = diff_bytes[:MAX_DIFF_BYTES].decode(errors="replace")
        log(f"Diff truncated to {MAX_DIFF_BYTES} bytes")

    log(f"Diff: {len(diff_bytes)} bytes. Sending to Claude...")

    # Call Claude
    try:
        parsed = claude_review(diff)
    except Exception as e:
        log(f"Claude API call failed: {e}")
        github_api(
            f"/repos/{os.environ['GITHUB_REPOSITORY']}/pulls/{pr_number}/reviews",
            method="POST",
            body={
                "body": f"🤖 Claude review failed.\n\n```\n{e}\n```",
                "event": "COMMENT",
            },
        )
        sys.exit(1)

    verdict = parsed.get("verdict", "COMMENT")
    summary = parsed.get("summary", "Claude reviewed this PR.")
    findings = parsed.get("findings", [])

    log(f"Claude returned {len(findings)} findings, verdict: {verdict}")

    # Build summary body
    emoji = {"REQUEST_CHANGES": "⚠️", "APPROVE": "✅"}.get(verdict, "💬")
    summary_body = (
        f"## 🤖 Claude Code Review{emoji}{focus_note}\n\n"
        f"{summary}\n\n"
        f"_{len(findings)} finding(s) — see inline comments below._\n\n"
        f"---\n"
        f"*Requested by @{comment_user} — [Claude Code](https://claude.com/claude-code)*"
    )

    post_review(pr_number, summary_body, findings, verdict, pr_files)


if __name__ == "__main__":
    main()
