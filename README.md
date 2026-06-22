# uruncode

Run Claude Code or Codex CLI through the UrunAI gateway with one local API key setup.

**Indonesian guide:** [README.id.md](README.id.md)

`uruncode` stores your UrunAI API key locally, prepares the environment/configuration required by your selected CLI, then launches either `claude` or `codex` for you.

> Requirements
>
> Install the CLI you want to use before running `uruncode`:
>
> - Claude Code: https://docs.claude.com/en/docs/claude-code
> - Codex CLI: https://developers.openai.com/codex

## Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.sh | bash
```

This installs `uruncode` to `~/.local/bin`. If that directory is not on your `PATH`, the installer prints the line you need to add.

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1 | iex
```

This installs `uruncode` to `%LOCALAPPDATA%\Programs\uruncode` and adds it to your user `PATH`. Open a new terminal after installation so the updated `PATH` is loaded.

## Quick Start

Run `uruncode` once:

```bash
uruncode
```

On the first run, `uruncode` asks for your UrunAI API key and saves it locally. After that, choose the tool you want to open:

```text
1) Claude Code
2) Codex CLI
```

You can also launch a tool directly:

```bash
uruncode claude .
uruncode codex .
```

Notes:

- `uruncode claude .` starts Claude Code in the current directory.
- `uruncode codex .` starts Codex CLI in the current directory using the `uruncode` profile.
- For Codex, when the first argument after `codex` is a directory, `uruncode` converts it to `codex --profile uruncode --cd <dir>`.

## Common Commands

| Command | Description |
| --- | --- |
| `uruncode` | Open an interactive menu to choose Claude Code or Codex CLI. |
| `uruncode claude [ARGS...]` | Run Claude Code through UrunAI. |
| `uruncode codex [ARGS...]` | Run Codex CLI through UrunAI. |
| `uruncode config` | Enter and save your UrunAI API key interactively. |
| `uruncode config <KEY>` | Save or replace your UrunAI API key directly. |
| `uruncode change-key` | Replace the stored UrunAI API key. |
| `uruncode reset` | Restore CLI config backups and remove the stored API key. |
| `uruncode update` | Re-run the installer to update `uruncode`. |
| `uruncode uninstall` | Windows only: remove `uruncode`, stored state, and PATH entry. |

`set-key`, `change`, and `change-key` are aliases for `config`/key replacement behavior.

## API Key

`uruncode` looks for an API key in this order:

1. A key passed with `uruncode config <KEY>` or `uruncode change-key <KEY>`.
2. The stored config file from a previous run.
3. `URUNAI_API_KEY` from your environment. If found, it is saved for the next run.
4. An interactive prompt.

Stored key path:

| Platform | Path |
| --- | --- |
| macOS/Linux | `~/.config/uruncode/config` |
| Windows | `%APPDATA%\uruncode\config` |

The key is stored in plaintext on your machine with user-only permissions where supported. Treat it like any other local credential.

## Config Backup and Reset

Before `uruncode` changes Claude Code or Codex CLI configuration, it saves the original file under the local `uruncode` config directory. Each backup is created once and is not overwritten by later runs.

Backed up files:

- Claude Code: `~/.claude/settings.json`
- Codex CLI: `$CODEX_HOME/config.toml` or `~/.codex/config.toml`
- Codex CLI `uruncode` profile: `$CODEX_HOME/uruncode.config.toml` or `~/.codex/uruncode.config.toml`

Run this command to restore backups and remove the stored UrunAI API key:

```bash
uruncode reset
```

If a file did not exist before `uruncode` created it, `reset` removes that file instead of restoring a backup.

## What It Configures

Default values:

```sh
URUNAI_BASE_URL="https://api.urunai.my.id/v1"
URUNAI_CLAUDE_MODEL="aim-cdx-mini"
URUNAI_CLAUDE_AUTH_MODE="bearer"
URUNAI_CODEX_MODEL="gpt-5.4-mini"
```

### Claude Code

By default, Claude Code is launched with gateway/bearer-token authentication:

```sh
ANTHROPIC_BASE_URL="$URUNAI_BASE_URL"
ANTHROPIC_AUTH_TOKEN="<your UrunAI API key>"
ANTHROPIC_MODEL="$URUNAI_CLAUDE_MODEL"
claude --model "$URUNAI_CLAUDE_MODEL" "$@"
```

Set `URUNAI_CLAUDE_AUTH_MODE=api-key` only if your gateway expects Anthropic-style `x-api-key` authentication. In that mode, `uruncode` uses `ANTHROPIC_API_KEY` instead of `ANTHROPIC_AUTH_TOKEN`.

`uruncode` also removes the inactive Claude auth variable from the launch environment/settings, so Claude Code does not mix API-key and bearer-token auth.

If you pass your own `--model` argument, `uruncode` respects it and does not add another model argument.

### Codex CLI

Codex launch creates or refreshes `$CODEX_HOME/uruncode.config.toml` or `~/.codex/uruncode.config.toml`:

```toml
model = "gpt-5.4-mini"
model_provider = "urunai"

[model_providers.urunai]
name = "UrunAI"
base_url = "https://api.urunai.my.id/v1"
wire_api = "responses"
env_key = "URUNAI_API_KEY"
```

Then runs:

```bash
codex --profile uruncode --cd .
```

## Update

```bash
uruncode update
```

On Windows, if Claude launch still shows a `[eval]` / `node -e` error, your installed `uruncode.ps1` may be an older copy. Re-run the installer to replace it:

```powershell
irm https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1 | iex
```

Override the installer URL when needed:

```bash
URUNCODE_INSTALL_URL=https://raw.githubusercontent.com/<owner>/<repo>/main/install.sh uruncode update
```

## Uninstall

Before deleting `uruncode`, restore CLI config backups and remove the stored UrunAI API key.

### macOS / Linux

```bash
uruncode reset
rm ~/.local/bin/uruncode
rm -rf ~/.config/uruncode
rm -f ~/.codex/uruncode.config.toml
```

### Windows (PowerShell)

```powershell
uruncode uninstall
```

This single command restores/removes `uruncode`-managed CLI config, removes the stored UrunAI API key, removes the install directory, and removes the install directory from your user `PATH`. Open a new terminal before reinstalling.

If `uruncode uninstall` prints `Unknown launcher: uninstall`, your installed `uruncode.ps1` is older than the uninstall command. Refresh it and uninstall in one PowerShell line:

```powershell
irm https://raw.githubusercontent.com/nugrahadevelopers/uruncode/main/install.ps1 | iex; uruncode uninstall
```

If you already followed older uninstall instructions and deleted `%APPDATA%\uruncode` first, manually remove only these keys from `%USERPROFILE%\.claude\settings.json`:

- `env.ANTHROPIC_BASE_URL`
- `env.ANTHROPIC_MODEL`
- `env.ANTHROPIC_API_KEY`
- `env.ANTHROPIC_AUTH_TOKEN`

Do not delete the whole Claude settings file unless you are sure it has no unrelated settings.

## Troubleshooting

### `claude CLI not found on PATH`

Install Claude Code first, then open a new terminal and run `uruncode claude .` again.

### `codex CLI not found on PATH`

Install Codex CLI first, then open a new terminal and run `uruncode codex .` again.

### The saved key is wrong

Run one of these commands:

```bash
uruncode change-key
uruncode change-key <NEW_KEY>
```

### I want to restore my previous Claude/Codex configuration

Run:

```bash
uruncode reset
```

This restores the backups created before `uruncode` changed the CLI configuration.
