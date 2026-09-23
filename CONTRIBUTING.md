# Contributing

The most useful report is a sentence halfsay got wrong, with its trace:

1. Run it with `--log`: `open build/halfsay.app --args --log`, or `swift run halfsay --log`.
2. Say the sentence, then open the newest file in `~/Library/Logs/halfsay/`.
3. Open an issue with the lines for that sentence. The log holds everything the mic heard, so cut anything private first.

## Changing the code

- `make test` has to pass, and new logic comes with a test in `Tests/`: the decision logic in `HalfsayCore` runs offline.
- Changing how Jev is asked (question wording, criteria, thresholds): run `swift run jev-probe` twice and put both scores in the pull request. It calls the real API with your key from `.env`, about a cent a run.
- Sentences added to the eval are made up, never someone's real speech.
- [AGENTS.md](AGENTS.md) lists the traps: Swift 6 isolation in Apple callbacks, and the bar that must never take focus.

Much of halfsay was written with [Claude Code](https://claude.com/claude-code); those commits say so.
