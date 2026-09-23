# Security and data handling

halfsay listens to your microphone and can type into the app in front, so this is exactly what it touches.

**What leaves your Mac.** Apple's speech recognizer turns your voice into text, on the Mac when your language supports it and on Apple's servers otherwise (the first line halfsay prints says which). halfsay sends that text, the name of the app in front and the names of your installed apps to TypeSafe's Jev at `api.typesafe.ai`, and nothing anywhere else. Searches and sites open in your browser like any link.

**The key.** Your Jev API key comes from `TYPESAFE_API_KEY` or from `~/.config/halfsay/api-key`, a file only your user can read. It goes only to TypeSafe, in the request's Authorization header, and is never written to a log. `.env` is ignored by Git; if a key leaks anyway, rotate it in the TypeSafe console.

**What it can do.** With Accessibility on, halfsay types text and presses ⌘N in the app in front. It never presses Return. Anyone who speaks near the mic while it listens can drive it, a video playing out loud included, so pause it with ⌥Space when you are not using it: the mic is off while paused.

**Logs.** `--log` is off by default. When on, `~/Library/Logs/halfsay/` keeps everything the mic heard. Delete it when you are done, and cut private lines before attaching any to an issue.

**Reporting a vulnerability.** Please don't open a public issue. Use [Report a vulnerability](../../security/advisories/new) on this repository, or reach the maintainer through their GitHub profile, and never include an API key or a full log.
