# SkillManager

A native macOS app to discover, install and manage [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Cowork](https://docs.anthropic.com/en/docs/claude-code/cowork) skills — no terminal required.

<div align="center">

https://github.com/km6rb6rnxh-dot/SkillManager/raw/main/demo.mp4

</div>

## What it does

SkillManager gives you a visual interface to extend Claude's capabilities:

- **Find** skills on GitHub by name or keyword
- **Install** with one click — choose Claude Code, Cowork, or both
- **Update** skills when new versions are available
- **Toggle** environments per skill without reinstalling
- **Resource mode** — repos without a SKILL.md get one auto-generated, so any markdown knowledge base becomes a Claude skill

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26+ (to build from source)
- Git installed at `/usr/local/bin/git`
- Optional: a GitHub personal access token for better search results

## Build & Run

```bash
git clone https://github.com/km6rb6rnxh-dot/SkillManager.git
cd SkillManager
open -a Xcode Package.swift
# Then press ⌘R to build and run
```

Or from the terminal:

```bash
swift build
open .build/debug/SkillManager.app
```

## How it works

SkillManager reads and writes the same files Claude Code uses:

| What | Where |
|------|-------|
| Installed skills | `~/.agents/skills/` |
| Claude Code symlinks | `~/.claude/skills/` |
| Skill registry | `~/.agents/.skill-lock.json` |
| Cowork config | `~/.agents/cowork.json` |

When you install a skill, SkillManager:

1. Downloads a compressed tarball from GitHub (faster than cloning)
2. Extracts and copies the skill folder to `~/.agents/skills/`
3. Creates a symlink in `~/.claude/skills/` (for Claude Code)
4. Registers the skill in `cowork.json` (for Cowork)
5. Records metadata in `.skill-lock.json` for update tracking

## Features

### Search & Install

The **Find Skills** search combines two GitHub APIs:
- **Code Search** (requires token) — finds repos with `SKILL.md` files matching your query
- **Repository Search** (no token needed) — finds repos by name and checks for skill content

Results are classified as **Skill** (has SKILL.md) or **Resource** (has markdown content). Resources get a SKILL.md generated automatically from their `.md` files.

### Environment Management

Each skill can be active in Claude Code, Cowork, or both. Toggle environments from the detail panel — SkillManager handles the symlinks and registry entries.

### Update Checking

SkillManager compares the installed skill's tree SHA against the latest on GitHub. When a new version is detected, an orange badge appears and you can update individually or all at once.

### Install Log

Every install and update action is logged with timestamps and severity levels. Open Settings → Log to see the full history, diagnose failures, or export the log as a text file.

### Themes

Choose between System, Light, or Dark appearance in Settings (⌘,). The light theme uses macOS liquid glass materials; the dark theme provides a comfortable low-light experience.

### Onboarding

A guided tutorial runs on first launch, walking through every feature. If you need to see it again, reset with:

```bash
defaults delete SkillManager onboardingCompleted
```

## Setting up a GitHub Token

A personal access token improves search results and avoids rate limits:

1. Go to [GitHub Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens?type=beta)
2. Create a **fine-grained** token
3. No special permissions needed — public repository access only
4. Paste it in SkillManager → Settings → GitHub → Save

## Project Structure

```
SkillManager/
├── Package.swift
└── SkillManager/
    ├── SkillManagerApp.swift        # App entry point
    ├── Models/
    │   ├── Skill.swift              # Skill model
    │   ├── SkillLockFile.swift      # Registry entries
    │   ├── SkillMetadata.swift      # SKILL.md frontmatter
    │   └── GitHubModels.swift       # API response types
    ├── Services/
    │   ├── ShellRunner.swift        # Git command execution
    │   ├── GitHubService.swift      # GitHub API client
    │   ├── SkillRegistry.swift      # Lock file management
    │   ├── SkillInstaller.swift     # Install/update/remove
    │   ├── CoworkRegistry.swift     # Cowork config management
    │   ├── UpdateChecker.swift      # Version comparison
    │   ├── FrontmatterParser.swift  # YAML frontmatter parsing
    │   └── InstallLogger.swift      # Install/update activity log
    ├── ViewModels/
    │   ├── SkillListViewModel.swift # Main list logic
    │   ├── AddSkillViewModel.swift  # Direct repo install
    │   └── FindSkillViewModel.swift # Search & install
    ├── Views/
    │   ├── ContentView.swift        # Split panel layout
    │   ├── SkillDetailView.swift    # Skill detail panel
    │   ├── SkillRowView.swift       # List row
    │   ├── FindSkillSheet.swift     # Search sheet
    │   ├── AddSkillSheet.swift      # Direct install sheet
    │   ├── SettingsView.swift       # Preferences
    │   ├── OnboardingView.swift     # First-launch tutorial
    │   └── Components/
    │       ├── EmptyStateView.swift
    │       └── UpdateBadge.swift
    └── Utilities/
        ├── Constants.swift
        └── AppTheme.swift           # Adaptive color system
```

## License

MIT

## Author

Built by [Andrea Curti](https://github.com/km6rb6rnxh-dot) with Claude.
