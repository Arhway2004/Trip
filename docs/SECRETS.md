# Keeping API keys private (e.g. aviationstack)

1. **The key lives on the backend only, never on the phone.** Put it in
   `secrets/aviationstack.env` (git-ignored). `make run` / `make run-mem` and
   `mobile/tool/run_phone.sh` load it into the backend only, and the server prints
   it as `[redacted]`. The phone has nothing to enter: its build includes the
   server address (not a secret), and it signs in by itself (demo account on a
   development server).
2. **If you'd rather keep it out of the project folder too:** keep it in the macOS Keychain, outside the project:
   ```bash
   security add-generic-password -a "$USER" -s wanderplan-aviationstack -w
   # (asks for the key without echoing it; nothing is saved in shell history)
   ```
3. **If a key file must live in the project:** put it in `secrets/` (or name it `*.key`).
   Those paths are git-ignored, and `.claude/settings.json` denies Claude Code's file
   tools from reading them. That is a guard rail, not a vault: Claude Code runs as your
   macOS user, so the macOS Keychain (option 2) is the stronger protection.
   For deployment, use your host's secret store (e.g. Fly/Render secrets), not a file.
4. **Don't pass keys with `--dart-define`:** Flutter writes them into
   `ios/Flutter/Generated.xcconfig` and into the app binary.
5. **Never paste a key into an AI chat, an issue, a screenshot or a commit.**
   If that happens, revoke it in the provider's dashboard and create a new one.
