# Skills

Load the matching skill before starting the task; if several fit, say which and why. When asked
"what skills do we have for X", answer from this map.

## Before writing tests (owner 10-21)

Load the matching skill when the task fits it:

- parsers, SQL queries and transactions, state machines, encode/decode or classifiers →
  `property-based-testing` (Hypothesis);
- a web UI → `webapp-testing`;
- a new or bumped dependency → `supply-chain-risk-auditor`.

Astra and Fable remain the reviews: do not add `/code-review` or `/security-review` on top of
them. Name the skills you used in the DONE block.

## Map

| Task | Use |
|---|---|
| Design/redesign UI: landing, dashboard, user cabinet, settings, onboarding; UI audit or polish | `impeccable` (`init` → `craft` → `audit`/`polish`) |
| Animation, micro-interactions | `emil-design-eng`; motion review: `/review-animations` |
| Mobile web, Telegram Mini Apps | `mobile-native` |
| Stress-test UI with worst-case data | `break-ui` |
| Pre-ship UI check | `web-design-guidelines` + `agent-browser` screenshots (desktop, mobile, dark) |
| Drive/test a web app, reproduce a frontend bug | `agent-browser` (interactive); `webapp-testing` (Playwright scripts) |
| Positioning → page copy → editing copy | `product-marketing` → `copywriting` → `copy-editing` |
| Conversion, launch, AI-search visibility | `cro`, `launch`, `ai-seo` |
| De-AI prose (posts, articles, docs) | `humanizer` (EN), `humanizer-ru` (RU; score via `uvx ru-humanizer`) |
| Build an MCP server | `mcp-builder`; test with `npx @modelcontextprotocol/inspector --cli` |
| Library/framework docs | context7 MCP — before relying on memory for versioned APIs |
| Word / PDF / slides / spreadsheets | `docx`, `pdf`, `pptx`, `xlsx` |
| Review, cleanup, security of a diff | `/code-review`, `/simplify`, `/security-review` (not on top of Astra or Fable reviews) |
| Security deep dive | SAST: `semgrep` / `codeql` skills; dependencies: `supply-chain-risk-auditor`; full verified scan: `claude-security` plugin (disabled by default — `claude plugin enable claude-security@claude-plugins-official`, disable after) |
| Property-based tests (Python) | `property-based-testing` (Hypothesis) |
| CI / Docker / secrets / deps linters (CLI) | `zizmor`, `actionlint`, `pinact`, `hadolint`, `gitleaks --redact`, `osv-scanner` |
| Destructive command blocked by dcg hook | Explain why it's needed; the user runs it or allowlists it — never work around the guard |
| Type errors | LSP diagnostics (pyright, typescript, clangd) appear after edits — fix before finishing |
| Language / infra conventions | Auto-loaded by file type from `~/.claude/rules/`: `frontend.md`, `python.md`, `devops.md` |

Tiden skills: modules/tiden/skills.md.
