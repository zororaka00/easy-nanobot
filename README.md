# 🤖 Easy Nanobot Setup

A helper script to install and configure [nanobot-ai](https://github.com/HKUDS/nanobot) on Debian/Ubuntu systems — with Telegram bot integration, web search, and OpenRouter support.

---

## 📁 Files

| File | Description |
|---|---|
| `setup-nanobot.sh` | Main installer script. Reads `~/easy-nanobot/config.json` and merges values into `~/.nanobot/config.json` |
| `config.json.example` | Example config — copy and edit before running the installer |
| `upgrade-nanobot.sh` | Upgrade script — stops tmux, upgrades nanobot via `uv`, and restarts the gateway |

---

## ⚙️ Prerequisites

Before running the installer, you need to prepare the following keys and tokens:

| Key | Where to Get It |
|---|---|
| `agents.defaults.model` | Model identifier, e.g. `openrouter/gpt-4o-mini` |
| `channels.telegram.token` | Telegram Bot token — see [BotFather guide](#-getting-a-telegram-bot-token) below |
| `channels.telegram.allowFrom` | List of allowed Telegram user IDs (integers) |
| `providers.openrouter.apiKey` | [openrouter.ai](https://openrouter.ai/) API key |
| `tools.web.search.apiKey` | [Brave Search API](https://brave.com/search/api/) key |

---

## 🚀 Installation

**1. Clone or download this repository into `~/easy-nanobot/`**

**2. Copy and edit the example config:**
```bash
cp ~/easy-nanobot/config.json.example ~/easy-nanobot/config.json
nano ~/easy-nanobot/config.json
```

**3. Run the installer:**
```bash
chmod +x ~/easy-nanobot/setup-nanobot.sh
bash ~/easy-nanobot/setup-nanobot.sh
```

### What the installer does

- Updates and upgrades system packages
- Installs `curl` and the `uv` package installer
- Ensures `python3` is available
- Installs `nanobot-ai` via `uv`
- Runs `nanobot onboard`
- Merges your `config.json` into `~/.nanobot/config.json`
- Installs `tmux` and starts a detached session named `nanobot-gateway` running `nanobot gateway`

---

## ⬆️ Upgrading

```bash
chmod +x ~/easy-nanobot/upgrade-nanobot.sh
bash ~/easy-nanobot/upgrade-nanobot.sh
```

> ⚠️ **Warning:** The upgrade script runs `tmux kill-server`, which **terminates all active tmux sessions** on the host. Save your work before running it.

The upgrade command used internally:
```bash
uv tool install --upgrade git+https://github.com/HKUDS/nanobot.git
```

---

## 🤖 Getting a Telegram Bot Token

1. Open Telegram and start a chat with [@BotFather](https://t.me/BotFather)
2. Send `/newbot` and follow the prompts:
   - Choose a display name
   - Choose a username (must end with `bot`)
3. BotFather will return a token like `123456789:ABCDefG...` — paste this into `channels.telegram.token`
4. To find your own Telegram user ID, message [@userinfobot](https://t.me/userinfobot) or use the Telegram `getUpdates` API method

---

## 🔍 Web Search (Brave Search API)

Sign up at [brave.com/search/api](https://brave.com/search/api/) and obtain an API key. Place it in `tools.web.search.apiKey`.

---

## 📝 Notes

- If `uv` or `nanobot` are not immediately found in your PATH after install, open a new shell or re-login so profile scripts are sourced.
- The installer does a best-effort merge into `~/.nanobot/config.json`. Inspect the file afterward and adjust as needed.
- If `tmux` is unavailable, the script will print instructions to start the gateway manually.

---

## 🆘 Support

If you need help generating keys or understanding the config structure, open an issue and include any relevant non-sensitive snippets. **Do not share secrets or API keys publicly.**