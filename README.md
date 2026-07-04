# treeclip 🌲

A native, lightweight macOS clipboard manager built for people working with AI
agents in the terminal (Claude Code, Codex, and friends).

> **Status:** early development (M0 — skeleton). Not yet usable.
> Building in public — expect the repo to be rough before v1.

## Why treeclip

Three things, in order of what makes it different:

1. **Agent paste channel.** Pasting 5,000 lines into a terminal agent means
   watching it render character-by-character. treeclip detects the frontmost
   terminal and, past a threshold, drops the text/image to a file and pastes a
   `@/path` reference instead — the agent reads the file, done in a second.
2. **Floating notes.** A persistent snippets surface pinned to the screen edge:
   click a note, it pastes into the frontmost agent. Your reusable prompts and
   context, one click away.
3. **A clipboard that doesn't bloat.** Maccy-grade native palette (fast, keyboard
   first) with a storage layer that keeps memory flat: images always go to disk,
   the list only ever touches thumbnails, and history is capped. Local-first,
   open source, no telemetry.

### Why not Raycast / Maccy / PasteBar?

- **Raycast** is a great clipboard *if that's all you need* — but its paste is
  generic (no agent channel), unlimited history is behind Pro, and it's a whole
  launcher to adopt. treeclip coexists with any launcher.
- **Maccy** has the right native palette but a storage architecture that grows
  memory without bound (images stored inline, whole history held in memory).
- **PasteBar** has a healthy storage backend but a heavy WebView UI, and its
  license (CC BY-NC) forbids commercial forks.

treeclip takes the good interaction model of Maccy, a genuinely lightweight
storage layer, and adds the agent workflow neither of them targets.

## Architecture

```
TreeCore   engine — storage / capture / paste routing / models (no UI)
   ↑
TreeUI     SwiftUI palette + floating notes
   ↑
TreeApp    thin assembly: menu bar, permissions, wiring
```

Build with SwiftPM (no Xcode required):

```bash
swift build
swift test
```

## Credits

The clipboard capture layer and palette interaction model are informed by
[Maccy](https://github.com/p0deje/Maccy) by Alex Rodionov (MIT). Any Maccy-derived
source retains its original copyright notice. treeclip's storage layer is a clean
reimplementation and shares no code with Maccy.

## License

[GPL-3.0](LICENSE) © Sam Cui.
