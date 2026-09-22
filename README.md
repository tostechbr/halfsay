# halfsaid

Voice control for macOS that acts on half a sentence. Say "can you open up the notes app for me and…" and Notes is open before you finish.

It asks [Jev](https://typesafe.ai/blog/introducing-system-one-models-and-jev) (TypeSafe's System One model) about every word you say. Jev returns typed decisions with probabilities, not text, in ~200 ms, so code can act mid-sentence.

> **Status: v0 in progress.** The decision engine and the probe work. Mic, actions and the floating bar are next.

## How it decides

- **Closed actions** (open an app, new item) fire mid-sentence once 2 partials in a row agree at ≥ 0.85.
- **Open actions** (search, website, type text) wait for the pause: "search norbert" is not "search norbert wiener" until you stop.
- **Jev never writes text.** Code cuts every span of what you said, Jev picks one, and it is copied verbatim.
- Firing consumes the words, so the rest of the sentence becomes the next command.

## Probe: when can you act on half a sentence?

`jev-probe` replays sentences word by word through the same engine and questions. It waits for each answer, so network lag is not counted.

| said | fired |
|---|---|
| can you open up the notes app for me and once you're there can you create a new note | open Notes after 7/19 words · new item after 19/19 |
| and inside this new note let's make the title say hello | type “hello” at the pause |
| can you open up safari and google search norbert wiener | open Safari after 6/10 · search “norbert wiener” at the pause |
| now can you open up x dot com | open https://x.com at the pause |
| abre o safari e pesquisa receita de pão de queijo | open Safari after 4/10 · search “receita de pão de queijo” at the pause |
| i was just telling my friend about the notes app | nothing: not a command |

68 calls, median 302 ms. Keep one connection warm: a fresh TLS handshake alone costs ~440 ms, a warm call ~205 ms.

```sh
export TYPESAFE_API_KEY=...   # https://console.typesafe.ai
swift run jev-probe
swift run jev-probe "open safari and search the weather in lisbon"
```

## Develop

`make test` runs `swift test`, adding Swift Testing's path when only the Command Line Tools are installed.

MIT
