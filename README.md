# halfsaid

Voice control for macOS that acts on half a sentence. Say "can you open up the notes app for me and…" and Notes is open before you finish.

It asks [Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev) (TypeSafe's System One model) about every word you say. Jev returns typed decisions with probabilities, not text, in ~200 ms, so code can act mid-sentence.

> **Status: v0 in progress.** Engine, probe, microphone, actions and the floating bar work. A demo GIF is next.

## Run it

```sh
echo 'TYPESAFE_API_KEY=...' > .env   # https://console.typesafe.ai
make key                             # copies it to ~/.config/halfsaid/api-key (an app opened from Finder has no shell env)
make app && open build/halfsaid.app  # a bar floats at the top: press ⌥Space and talk
open build/halfsaid.app --args --dry-run --log   # show what it would do, keep a local trace
swift run halfsaid --text "open safari and search the weather in lisbon" --dry-run   # no mic: words fed at 160 wpm
```

While you talk the bar shows Jev's read: the three likeliest actions, the yes/no "opens an app?" and each command as it fires. It collapses to a pill when you stop. It never takes focus, so typing lands in the app you are using.

Apple's recognizer transcribes your speech in your Mac's language (`--locale en-US` to pick another), on this Mac when that language supports it. Only the words go to Jev. The first run asks for Microphone and Speech Recognition access. Typing and ⌘N also need Accessibility for your terminal.

`--log` keeps a local trace in `~/Library/Logs/halfsaid/`, one JSON line per event (heard, asked, Jev's answer, fired, ran). It records everything the mic hears, side conversations included, and never leaves your Mac. Off by default.

## How it decides

- **Closed actions** fire mid-sentence once 2 partials in a row agree. Opening an app needs the app named beyond doubt (≥ 0.95) and ≥ 0.8 from the action choice or from a yes/no "does it ask to open an app?". The yes/no holds up when a second command follows ("abre as notas e digita…"), where the single choice splits between two valid actions. A new item needs ≥ 0.85.
- **Open actions** (search, website, type text) wait for the pause: "search norbert" is not "search norbert wiener" until you stop.
- **Jev never writes text.** Code cuts every span of what you said, Jev picks one, and it is copied verbatim.
- Firing consumes the words, so the rest of the sentence becomes the next command.
- Search, website and typing use words only up to their argument, so "search cake recipes and open notes" runs both.

## Measured at speaking pace

`--text` at 160 wpm, network included:

| said | fired |
|---|---|
| can you open up the notes app for me and once you're there can you create a new note and inside this new note let's make the title say hello | open Notes **8.3 s before the end** · new item 3.5 s before · type “hello” 0.6 s after |
| can you open up safari and google search norbert wiener | open Safari 1.3 s before · search “norbert wiener” 0.6 s after |
| abre o safari e pesquisa receita de pão de queijo | open Safari 2.0 s before · search “receita de pão de queijo” 0.6 s after |
| i was just telling my friend about the notes app | nothing: not a command |

Open actions land ~0.6 s after you stop. That is the pause they wait for; Jev's answer is already in.

## Probe

`swift run jev-probe` replays sentences word by word and waits for each answer, printing a per-word table of what Jev decided and how few words each command needed ("open Notes after 7/19 words"). Median 302 ms over 68 calls. Keep one connection warm: a fresh TLS handshake alone costs ~440 ms, a warm call ~205 ms.

## Develop

`make test` runs `swift test`, adding Swift Testing's path when only the Command Line Tools are installed.

MIT
