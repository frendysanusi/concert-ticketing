# AI PR review

`.github/workflows/pr-review.yml` uses the pinned `anthropics/claude-code-action`
through OpenRouter. It runs on opened, updated, reopened, and ready-for-review PRs
from branches in this repository. Drafts and fork PRs are skipped. The job is
advisory and should not be a required merge check.

## Setup

Add these repository secrets under Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `OPENROUTER_API_KEY` | Your OpenRouter API key |
| `OPENROUTER_MODEL` | The full model ID, for example `google/gemma-4-31b-it:free` |

Free and paid model IDs are accepted. The selected model is also assigned to the
runtime's Haiku, Sonnet, and Opus aliases. Neither the key nor a model ID is
hardcoded into the workflow. Missing secrets skip review with a notice.

The model must support tool calling through OpenRouter's Anthropic-compatible API.
[OpenRouter documents this action integration](https://openrouter.ai/docs/cookbook/coding-agents/claude-code-integration),
but guarantees Claude Code compatibility only with Anthropic's first-party provider.
Gemma and other providers need a live compatibility check with the configured key;
the model's standalone benchmarks do not establish agent-runtime compatibility.

## Review policy

The versioned policy is `.github/prompts/pr-review.md`, adapted from the
[PR review skill](https://github.com/frendysanusi/skills/blob/930fafa37cb1224ea7c371ed1ae65a06da322274/skills/pr-review/SKILL.md).
It requires tracing evidence, concrete examples, exact source references, and
short actionable findings. Unverified numerical claims and design preferences
must not be presented as defects.

The workflow checks out the PR's trusted base and appends that policy to the
system prompt. The agent reads the PR diff, head source, callers, tests, and CI
results using GitHub's API. Its tools permit local reads and selected `gh` read
and comment commands; project execution, editing tools, and MCP tools are not
enabled. The token grants repository reads and PR comment writes, with no content
write permission. The action also retains its default actor-permission checks.

The policy directs the agent to verify the current head before publishing and
create or update one `github-actions[bot]` comment beginning with
`<!-- concert-ticketing-ai-review -->`. Results cite the reviewed commit and state
coverage limitations. It does not approve or request changes. A run is limited
to 20 model turns and 15 minutes; provider errors remain advisory.

Because the workflow reads its prompt from the base commit, merge these files into
the target branch before expecting it to review later PRs. The review step skips
when the base does not contain the prompt. Changes to the prompt
take effect after they merge into the target branch too.

## Validation

Run `make workflow-check` to lint both workflows. Configuration checks can run
without provider credentials. A live agent review requires the two secrets and a
GitHub Actions run; it has not been verified locally and no comments were posted
during implementation.
