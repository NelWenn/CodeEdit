<p align="center">
  <img src="https://github.com/CodeEditApp/CodeEdit/blob/main/.github/CodeEdit-Icon-128@2x.png?raw=true" height="128">
  <h1 align="center">CodeEditAi</h1>
  <p align="center"><i>A native macOS AI-first IDE — a fork of <a href="https://github.com/CodeEditApp/CodeEdit">CodeEdit</a>.</i></p>
</p>

<p align="center">
  <img alt="Platform macOS 26+" src="https://img.shields.io/badge/platform-macOS%2026%2B%20(Tahoe%20%2F%2027)-black.svg?style=for-the-badge&logo=apple">
  <img alt="Built with Claude" src="https://img.shields.io/badge/built%20with-Claude-black.svg?style=for-the-badge">
  <a aria-label="Based on CodeEdit" href="https://github.com/CodeEditApp/CodeEdit" target="_blank">
    <img alt="Based on CodeEdit" src="https://img.shields.io/badge/based%20on-CodeEdit-black.svg?style=for-the-badge">
  </a>
</p>

**CodeEditAi** is a personal fork of [CodeEdit](https://github.com/CodeEditApp/CodeEdit) that turns the community's native macOS code editor into an **AI-first IDE**. It keeps everything that makes CodeEdit great — a fully native, non-Electron editor with syntax highlighting, project find & replace, a terminal, and git integration — and layers on a built-in Claude coding agent, an ambient Spotify player, Discord Rich Presence, and a top-to-bottom **macOS Liquid Glass** redesign.

<img width="1012" alt="github-banner" src="https://user-images.githubusercontent.com/806104/194004176-3143d19f-1ad9-449c-bd41-8c4f9998f44b.png">

[![GitHub stars](https://img.shields.io/github/stars/NelWenn/CodeEdit?style=flat-square)](https://github.com/NelWenn/CodeEdit/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/NelWenn/CodeEdit?style=flat-square)](https://github.com/NelWenn/CodeEdit/network/members)
[![Upstream](https://img.shields.io/badge/upstream-CodeEditApp%2FCodeEdit-orange?style=flat-square)](https://github.com/CodeEditApp/CodeEdit)
[![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#license)

> [!IMPORTANT]
> CodeEditAi is an experimental personal fork built on top of CodeEdit's pre-release codebase. It is **not affiliated with or endorsed by the CodeEdit project**, targets the macOS 26/27 toolchain (Xcode 26/27), and is intended for personal use and experimentation. For the upstream editor, see [CodeEditApp/CodeEdit](https://github.com/CodeEditApp/CodeEdit).

## Table of Contents

- [What's new in this fork](#whats-new-in-this-fork)
- [Liquid Glass redesign](#liquid-glass-redesign)
- [Building from source](#building-from-source)
- [Credits](#credits)
- [Contributors](#contributors)
- [License](#license)

## What's new in this fork

CodeEditAi adds four headline features on top of CodeEdit:

### 🤖 Claude coding agent — sessions & tabs

A built-in [Claude](https://www.anthropic.com/claude) coding agent lives right inside the workspace, alongside the editor and terminal:

- **Agent mode** runs the Claude CLI directly in the editor area, themed to match your light/dark editor theme.
- **Multi-tab sessions** — open a new Claude tab to start a fresh session, with a Chrome-style Liquid Glass tab bar that mirrors the editor's own tabs.
- **Session history** — every conversation is saved per project. A new **Sessions** inspector lists all of the project's past sessions and lets you reopen one in the current tab (the default) or in a new tab. Open tabs are restored when you reopen the workspace.
- **Claude inspector** — an **Info** panel surfaces your account, plan, live usage, and the active model and reasoning effort.

### 🎵 Spotify player

A Liquid Glass mini-player in the toolbar replaces the old task UI:

- Sign in with your own Spotify account (OAuth 2.0 with PKCE — no client secret stored in the app).
- Now-playing artwork, title and artist, with play/pause, previous/next, an inline scrubber, a like button, and a volume slider.
- Built directly on the Spotify Web API. *(Playback control requires a Spotify Premium account.)*

### 🎮 Discord Rich Presence

Show what you're working on in CodeEditAi on your Discord profile, like the VS Code presence extension:

- Displays the app, the **project folder**, your **git branch**, an editing/idle status, and elapsed time.
- **Privacy-first:** folder-only — it never transmits file names. Turn it off with a single switch in Settings.

### 🌗 Light theme fixes

The Claude agent terminal and the bottom terminal now correctly follow your selected light/dark theme — no more black highlights or unreadable colors in light mode.

## Liquid Glass redesign

CodeEditAi adopts Apple's new **Liquid Glass** design language (macOS 26 Tahoe / macOS 27) across all of the new surfaces, so they feel like a natural part of the system:

- Native `NSGlassEffectView` / SwiftUI `.glassEffect()` for the Claude tab bar and the session selection.
- Translucent inspector panels that match the left-hand navigator, using proper vibrancy materials.
- A capsule Liquid Glass toolbar player that sits inside the native macOS 26 toolbar glass — no double pills.
- Hover states, rounded corners, and accessibility-minded hit targets throughout the new UI.

Each Liquid Glass surface is guarded by availability checks, so the app still builds and runs cleanly, falling back gracefully on earlier macOS releases.

## Building from source

> [!NOTE]
> The Liquid Glass surfaces use the **macOS 26/27 SDK**, so you need a matching **Xcode 26/27** toolchain to build.

```bash
git clone https://github.com/NelWenn/CodeEdit.git
cd CodeEdit
open CodeEdit.xcodeproj   # then Run (⌘R) in Xcode
```

Or build a release `.app` from the command line:

```bash
xcodebuild -project CodeEdit.xcodeproj -scheme CodeEdit -configuration Release \
  -destination 'platform=macOS,arch=arm64' -skipPackagePluginValidation build
```

To use the integrations you'll also need the [Claude CLI](https://www.anthropic.com/claude) installed, a Spotify account for the player, and a Discord application ID plus the Discord desktop app running for Rich Presence.

## Credits

CodeEditAi is built on the incredible work of the **[CodeEdit](https://github.com/CodeEditApp/CodeEdit)** project and its community — the entire native editor, git integration, terminal, language support, and source-editor engine come from them. Huge thanks to [Austin Condiff](https://github.com/austincondiff) and [all of CodeEdit's contributors](#contributors) (listed below, unchanged from upstream).

- **Fork & AI integration:** [NelWenn](https://github.com/NelWenn)
- **Original editor:** [CodeEdit](https://github.com/CodeEditApp/CodeEdit) by the CodeEdit community (MIT)

CodeEditAi is a personal IDE tailored to my own workflow and preferences, shared as-is. It's a separate project from CodeEdit and isn't seeking contributions — if you're after the community editor itself, head to [CodeEditApp/CodeEdit](https://github.com/CodeEditApp/CodeEdit).

## Contributors

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tbody>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://www.austincondiff.com"><img src="https://avatars.githubusercontent.com/u/806104?v=4?s=100" width="100px;" alt="Austin Condiff"/><br /><sub><b>Austin Condiff</b></sub></a><br /><a href="#design-austincondiff" title="Design">🎨</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=austincondiff" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://lukaspistrol.com"><img src="https://avatars.githubusercontent.com/u/9460130?v=4?s=100" width="100px;" alt="Lukas Pistrol"/><br /><sub><b>Lukas Pistrol</b></sub></a><br /><a href="#infra-lukepistrol" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=lukepistrol" title="Tests">⚠️</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=lukepistrol" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://blog.windchillmedia.com"><img src="https://avatars.githubusercontent.com/u/35942988?v=4?s=100" width="100px;" alt="Khan Winter"/><br /><sub><b>Khan Winter</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=thecoolwinter" title="Code">💻</a> <a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Athecoolwinter" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/matthijseikelenboom"><img src="https://avatars.githubusercontent.com/u/1364843?v=4?s=100" width="100px;" alt="Matthijs Eikelenboom"/><br /><sub><b>Matthijs Eikelenboom</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=matthijseikelenboom" title="Code">💻</a> <a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Amatthijseikelenboom" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Wouter01"><img src="https://avatars.githubusercontent.com/u/62355975?v=4?s=100" width="100px;" alt="Wouter Hennen"/><br /><sub><b>Wouter Hennen</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Wouter01" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://wdg.codes"><img src="https://avatars.githubusercontent.com/u/1290461?v=4?s=100" width="100px;" alt="Wesley De Groot"/><br /><sub><b>Wesley De Groot</b></sub></a><br /><a href="#infra-0xWDG" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=0xWDG" title="Tests">⚠️</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=0xWDG" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/KaiTheRedNinja"><img src="https://avatars.githubusercontent.com/u/88234730?v=4?s=100" width="100px;" alt="KaiTheRedNinja"/><br /><sub><b>KaiTheRedNinja</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=KaiTheRedNinja" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/pkasila"><img src="https://avatars.githubusercontent.com/u/17158860?v=4?s=100" width="100px;" alt="Pavel Kasila"/><br /><sub><b>Pavel Kasila</b></sub></a><br /><a href="#infra-pkasila" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=pkasila" title="Tests">⚠️</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=pkasila" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/MarcoCarnevali"><img src="https://avatars.githubusercontent.com/u/9656572?v=4?s=100" width="100px;" alt="Marco Carnevali"/><br /><sub><b>Marco Carnevali</b></sub></a><br /><a href="#infra-MarcoCarnevali" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=MarcoCarnevali" title="Tests">⚠️</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=MarcoCarnevali" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/nanashili"><img src="https://avatars.githubusercontent.com/u/63672227?v=4?s=100" width="100px;" alt="Nanashi Li"/><br /><sub><b>Nanashi Li</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=nanashili" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://ninjiacoder.me"><img src="https://avatars.githubusercontent.com/u/22616933?v=4?s=100" width="100px;" alt="ninjiacoder"/><br /><sub><b>ninjiacoder</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=RayZhao1998" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://twitch.tv/Jeehut"><img src="https://avatars.githubusercontent.com/u/6942160?v=4?s=100" width="100px;" alt="Cihat Gündüz"/><br /><sub><b>Cihat Gündüz</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Jeehut" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/MysteryCoder456"><img src="https://avatars.githubusercontent.com/u/43755491?v=4?s=100" width="100px;" alt="Rehatbir Singh"/><br /><sub><b>Rehatbir Singh</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=MysteryCoder456" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Angelk90"><img src="https://avatars.githubusercontent.com/u/20476002?v=4?s=100" width="100px;" alt="Angelk90"/><br /><sub><b>Angelk90</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Angelk90" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://www.stefkors.com"><img src="https://avatars.githubusercontent.com/u/11800807?v=4?s=100" width="100px;" alt="Stef Kors"/><br /><sub><b>Stef Kors</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=StefKors" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://akringblog.com/"><img src="https://avatars.githubusercontent.com/u/6525286?v=4?s=100" width="100px;" alt="Chris Akring"/><br /><sub><b>Chris Akring</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=akring" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/highjeans"><img src="https://avatars.githubusercontent.com/u/77588045?v=4?s=100" width="100px;" alt="highjeans"/><br /><sub><b>highjeans</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=highjeans" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/jasonplatts"><img src="https://avatars.githubusercontent.com/u/48892071?v=4?s=100" width="100px;" alt="Jason Platts"/><br /><sub><b>Jason Platts</b></sub></a><br /><a href="#infra-jasonplatts" title="Infrastructure (Hosting, Build-Tools, etc)">🚇</a> <a href="#plugin-jasonplatts" title="Plugin/utility libraries">🔌</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/dzign1"><img src="https://avatars.githubusercontent.com/u/44317715?v=4?s=100" width="100px;" alt="Rob Hughes"/><br /><sub><b>Rob Hughes</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=dzign1" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://lingxi.li"><img src="https://avatars.githubusercontent.com/u/36816148?v=4?s=100" width="100px;" alt="Lingxi Li"/><br /><sub><b>Lingxi Li</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=lilingxi01" title="Code">💻</a> <a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Alilingxi01" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/octree"><img src="https://avatars.githubusercontent.com/u/7934444?v=4?s=100" width="100px;" alt="HZ.Liu"/><br /><sub><b>HZ.Liu</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=octree" title="Code">💻</a> <a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aoctree" title="Bug reports">🐛</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://www.youtube.com/channel/UCx1gvWpy5zjOd7yZyDwmXEA?sub_confirmation=1"><img src="https://avatars.githubusercontent.com/u/8013017?v=4?s=100" width="100px;" alt="Richard Topchii"/><br /><sub><b>Richard Topchii</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=richardtop" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Pythonen"><img src="https://avatars.githubusercontent.com/u/53183345?v=4?s=100" width="100px;" alt="Pythonen"/><br /><sub><b>Pythonen</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Pythonen" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/jav-solo"><img src="https://avatars.githubusercontent.com/u/10246220?v=4?s=100" width="100px;" alt="Javier Solorzano"/><br /><sub><b>Javier Solorzano</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=jav-solo" title="Code">💻</a> <a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Ajav-solo" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://angcosmin.com"><img src="https://avatars.githubusercontent.com/u/8146514?v=4?s=100" width="100px;" alt="Cosmin Anghel"/><br /><sub><b>Cosmin Anghel</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=AngCosmin" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://mmshivesh.ml"><img src="https://avatars.githubusercontent.com/u/23611514?v=4?s=100" width="100px;" alt="Shivesh"/><br /><sub><b>Shivesh</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=mmshivesh" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/drucelweisse"><img src="https://avatars.githubusercontent.com/u/36012972?v=4?s=100" width="100px;" alt="Andrey Plotnikov"/><br /><sub><b>Andrey Plotnikov</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=drucelweisse" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/POPOBE97"><img src="https://avatars.githubusercontent.com/u/7891810?v=4?s=100" width="100px;" alt="POPOBE97"/><br /><sub><b>POPOBE97</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=POPOBE97" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/nrudnyk"><img src="https://avatars.githubusercontent.com/u/20221382?v=4?s=100" width="100px;" alt="nrudnyk"/><br /><sub><b>nrudnyk</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=nrudnyk" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/benkoska"><img src="https://avatars.githubusercontent.com/u/17319613?v=4?s=100" width="100px;" alt="Ben Koska"/><br /><sub><b>Ben Koska</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=benkoska" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/evolify"><img src="https://avatars.githubusercontent.com/u/12669069?v=4?s=100" width="100px;" alt="evolify"/><br /><sub><b>evolify</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aevolify" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/shibotong"><img src="https://avatars.githubusercontent.com/u/44807628?v=4?s=100" width="100px;" alt="Shibo Tong"/><br /><sub><b>Shibo Tong</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=shibotong" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://ethanwong.me"><img src="https://avatars.githubusercontent.com/u/8158163?v=4?s=100" width="100px;" alt="Ethan Wong"/><br /><sub><b>Ethan Wong</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=GetToSet" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://gantoreno.com"><img src="https://avatars.githubusercontent.com/u/43397475?v=4?s=100" width="100px;" alt="Gabriel Moreno"/><br /><sub><b>Gabriel Moreno</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Agantoreno" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Prince213"><img src="https://avatars.githubusercontent.com/u/25235514?v=4?s=100" width="100px;" alt="Sizhe Zhao"/><br /><sub><b>Sizhe Zhao</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3APrince213" title="Bug reports">🐛</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Muhammed9991"><img src="https://avatars.githubusercontent.com/u/80204376?v=4?s=100" width="100px;" alt="Muhammed Mahmood"/><br /><sub><b>Muhammed Mahmood</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Muhammed9991" title="Code">💻</a> <a href="#maintenance-Muhammed9991" title="Maintenance">🚧</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/muescha"><img src="https://avatars.githubusercontent.com/u/184316?v=4?s=100" width="100px;" alt="Muescha"/><br /><sub><b>Muescha</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=muescha" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://alexsinelnikov.io/"><img src="https://avatars.githubusercontent.com/u/1757017?v=4?s=100" width="100px;" alt="Alex Sinelnikov"/><br /><sub><b>Alex Sinelnikov</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=avdept" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://pribess.github.io"><img src="https://avatars.githubusercontent.com/u/72389357?v=4?s=100" width="100px;" alt="Heewon Cho"/><br /><sub><b>Heewon Cho</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3APribess" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://www.xcodes.app"><img src="https://avatars.githubusercontent.com/u/1119565?v=4?s=100" width="100px;" alt="Matt Kiazyk"/><br /><sub><b>Matt Kiazyk</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=MattKiazyk" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/DingoBits"><img src="https://avatars.githubusercontent.com/u/107956274?v=4?s=100" width="100px;" alt="DingoBits"/><br /><sub><b>DingoBits</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=DingoBits" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/sk409"><img src="https://avatars.githubusercontent.com/u/25968819?v=4?s=100" width="100px;" alt="Shoto Kobayashi"/><br /><sub><b>Shoto Kobayashi</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Ask409" title="Bug reports">🐛</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=sk409" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://www.linkedin.com/in/aaryankotharii"><img src="https://avatars.githubusercontent.com/u/53724307?v=4?s=100" width="100px;" alt="Aaryan Kothari"/><br /><sub><b>Aaryan Kothari</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aaaryankotharii" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://kyleye.top/"><img src="https://avatars.githubusercontent.com/u/43724855?v=4?s=100" width="100px;" alt="Kyle"/><br /><sub><b>Kyle</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Kyle-Ye" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/NakaokaRei"><img src="https://avatars.githubusercontent.com/u/39183069?v=4?s=100" width="100px;" alt="Nakaoka Rei"/><br /><sub><b>Nakaoka Rei</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=NakaokaRei" title="Code">💻</a> <a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3ANakaokaRei" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/alexdeem"><img src="https://avatars.githubusercontent.com/u/404584?v=4?s=100" width="100px;" alt="Alex Deem"/><br /><sub><b>Alex Deem</b></sub></a><br /><a href="#maintenance-alexdeem" title="Maintenance">🚧</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/denizak"><img src="https://avatars.githubusercontent.com/u/1758456?v=4?s=100" width="100px;" alt="deni zakya"/><br /><sub><b>deni zakya</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Adenizak" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ahmdyasser"><img src="https://avatars.githubusercontent.com/u/42544598?v=4?s=100" width="100px;" alt="Ahmad Yasser"/><br /><sub><b>Ahmad Yasser</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aahmdyasser" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ezraberch"><img src="https://avatars.githubusercontent.com/u/49635435?v=4?s=100" width="100px;" alt="ezraberch"/><br /><sub><b>ezraberch</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=ezraberch" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Eliulm"><img src="https://avatars.githubusercontent.com/u/82230675?v=4?s=100" width="100px;" alt="Elias Wahl"/><br /><sub><b>Elias Wahl</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3AEliulm" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/bombardier200"><img src="https://avatars.githubusercontent.com/u/25121427?v=4?s=100" width="100px;" alt="bombardier200"/><br /><sub><b>bombardier200</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=bombardier200" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/yapryntsev"><img src="https://avatars.githubusercontent.com/u/18378212?v=4?s=100" width="100px;" alt="Alex Yapryntsev"/><br /><sub><b>Alex Yapryntsev</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=yapryntsev" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Code-DJ"><img src="https://avatars.githubusercontent.com/u/8212554?v=4?s=100" width="100px;" alt="Code-DJ"/><br /><sub><b>Code-DJ</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Code-DJ" title="Code">💻</a> <a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3ACode-DJ" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/neilZon"><img src="https://avatars.githubusercontent.com/u/46465568?v=4?s=100" width="100px;" alt="Neilzon Viloria"/><br /><sub><b>Neilzon Viloria</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3AneilZon" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://cubik65536.top"><img src="https://avatars.githubusercontent.com/u/72877496?v=4?s=100" width="100px;" alt="Cubik"/><br /><sub><b>Cubik</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3ACubik65536" title="Bug reports">🐛</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Cubik65536" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://twitter.com/RenanGreca"><img src="https://avatars.githubusercontent.com/u/5760386?v=4?s=100" width="100px;" alt="Renan Greca"/><br /><sub><b>Renan Greca</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=RenanGreca" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/maxkel"><img src="https://avatars.githubusercontent.com/u/46418077?v=4?s=100" width="100px;" alt="maxkel"/><br /><sub><b>maxkel</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Amaxkel" title="Bug reports">🐛</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=maxkel" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://scrapp08.xyz"><img src="https://avatars.githubusercontent.com/u/105889363?v=4?s=100" width="100px;" alt="Scrap"/><br /><sub><b>Scrap</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=scrapp08" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/iggy890"><img src="https://avatars.githubusercontent.com/u/98705626?v=4?s=100" width="100px;" alt="iggy890"/><br /><sub><b>iggy890</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=iggy890" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/stavares843"><img src="https://avatars.githubusercontent.com/u/29093946?v=4?s=100" width="100px;" alt="Sara Tavares"/><br /><sub><b>Sara Tavares</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Astavares843" title="Bug reports">🐛</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=stavares843" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/luah5"><img src="https://avatars.githubusercontent.com/u/128280019?v=4?s=100" width="100px;" alt="luah5"/><br /><sub><b>luah5</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=luah5" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/evanlwang"><img src="https://avatars.githubusercontent.com/u/71157264?v=4?s=100" width="100px;" alt="Evan Wang"/><br /><sub><b>Evan Wang</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=evanlwang" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/dscyrescotti"><img src="https://avatars.githubusercontent.com/u/67727096?v=4?s=100" width="100px;" alt="Dscyre Scotti"/><br /><sub><b>Dscyre Scotti</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=dscyrescotti" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://tomasboda.com"><img src="https://avatars.githubusercontent.com/u/40064599?v=4?s=100" width="100px;" alt="Tomáš Boďa"/><br /><sub><b>Tomáš Boďa</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Advandyy" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Ahattalla"><img src="https://avatars.githubusercontent.com/u/53402452?v=4?s=100" width="100px;" alt="Ahmed Attalla"/><br /><sub><b>Ahmed Attalla</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3AAhattalla" title="Bug reports">🐛</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Ahattalla" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://estebanborai.com"><img src="https://avatars.githubusercontent.com/u/34756077?v=4?s=100" width="100px;" alt="Esteban Borai"/><br /><sub><b>Esteban Borai</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=EstebanBorai" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/avinizhanov"><img src="https://avatars.githubusercontent.com/u/42622715?v=4?s=100" width="100px;" alt="avinizhanov"/><br /><sub><b>avinizhanov</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aavinizhanov" title="Bug reports">🐛</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=avinizhanov" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/kmohsin11"><img src="https://avatars.githubusercontent.com/u/28269317?v=4?s=100" width="100px;" alt="kmohsin11"/><br /><sub><b>kmohsin11</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Akmohsin11" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/armartinez"><img src="https://avatars.githubusercontent.com/u/1909987?v=4?s=100" width="100px;" alt="Axel Martinez"/><br /><sub><b>Axel Martinez</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aarmartinez" title="Bug reports">🐛</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=armartinez" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://nivora.app"><img src="https://avatars.githubusercontent.com/u/5382443?v=4?s=100" width="100px;" alt="Federico Zivolo"/><br /><sub><b>Federico Zivolo</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=FezVrasta" title="Code">💻</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/ElvisWong213"><img src="https://avatars.githubusercontent.com/u/40566101?v=4?s=100" width="100px;" alt="Elvis Wong"/><br /><sub><b>Elvis Wong</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3AElvisWong213" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://ibrahimcetin.dev"><img src="https://avatars.githubusercontent.com/u/33904390?v=4?s=100" width="100px;" alt="İbrahim Çetin"/><br /><sub><b>İbrahim Çetin</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aibrahimcetin" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/phlpsong"><img src="https://avatars.githubusercontent.com/u/103433299?v=4?s=100" width="100px;" alt="phlpsong"/><br /><sub><b>phlpsong</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aphlpsong" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://ahnafmahmud.com"><img src="https://avatars.githubusercontent.com/u/44692189?v=4?s=100" width="100px;" alt="Ahnaf Mahmud"/><br /><sub><b>Ahnaf Mahmud</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=infinitepower18" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/DanKlaver15"><img src="https://avatars.githubusercontent.com/u/9391497?v=4?s=100" width="100px;" alt="Dan K"/><br /><sub><b>Dan K</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=DanKlaver15" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://knotbin.xyz"><img src="https://avatars.githubusercontent.com/u/118622417?v=4?s=100" width="100px;" alt="Roscoe Rubin-Rottenberg"/><br /><sub><b>Roscoe Rubin-Rottenberg</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=knotbin" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/plbstl"><img src="https://avatars.githubusercontent.com/u/49006567?v=4?s=100" width="100px;" alt="Paul Ebose"/><br /><sub><b>Paul Ebose</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Aplbstl" title="Bug reports">🐛</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="http://danielz.xyz"><img src="https://avatars.githubusercontent.com/u/65467530?v=4?s=100" width="100px;" alt="Daniel Zhu"/><br /><sub><b>Daniel Zhu</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Adanielzsh" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/simonwhitaker"><img src="https://avatars.githubusercontent.com/u/116432?v=4?s=100" width="100px;" alt="Simon Whitaker"/><br /><sub><b>Simon Whitaker</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Asimonwhitaker" title="Bug reports">🐛</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/LeonardoLarranaga"><img src="https://avatars.githubusercontent.com/u/83844690?v=4?s=100" width="100px;" alt="Leonardo"/><br /><sub><b>Leonardo</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=LeonardoLarranaga" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/scaredcr6w"><img src="https://avatars.githubusercontent.com/u/85457088?v=4?s=100" width="100px;" alt="Levente Anda"/><br /><sub><b>Levente Anda</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=scaredcr6w" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://nobelliu.github.com"><img src="https://avatars.githubusercontent.com/u/10796646?v=4?s=100" width="100px;" alt="Nobel"/><br /><sub><b>Nobel</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=NobelLiu" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/SavelyUkuren"><img src="https://avatars.githubusercontent.com/u/125015568?v=4?s=100" width="100px;" alt="Savely"/><br /><sub><b>Savely</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=SavelyUkuren" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Kihron"><img src="https://avatars.githubusercontent.com/u/30128800?v=4?s=100" width="100px;" alt="Kihron"/><br /><sub><b>Kihron</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3AKihron" title="Bug reports">🐛</a></td>
    </tr>
    <tr>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/pro100filipp"><img src="https://avatars.githubusercontent.com/u/12880697?v=4?s=100" width="100px;" alt="Filipp Kuznetsov"/><br /><sub><b>Filipp Kuznetsov</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=pro100filipp" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/rustemd02"><img src="https://avatars.githubusercontent.com/u/11714456?v=4?s=100" width="100px;" alt="rustemd02"/><br /><sub><b>rustemd02</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/issues?q=author%3Arustemd02" title="Bug reports">🐛</a> <a href="https://github.com/CodeEditApp/CodeEdit/commits?author=rustemd02" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/SimonKudsk"><img src="https://avatars.githubusercontent.com/u/10168417?v=4?s=100" width="100px;" alt="Simon Kudsk"/><br /><sub><b>Simon Kudsk</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=SimonKudsk" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/Syrux64"><img src="https://avatars.githubusercontent.com/u/118998822?v=4?s=100" width="100px;" alt="Surya"/><br /><sub><b>Surya</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=Syrux64" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="https://github.com/georgetchelidze"><img src="https://avatars.githubusercontent.com/u/96194129?v=4?s=100" width="100px;" alt="George Tchelidze"/><br /><sub><b>George Tchelidze</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=georgetchelidze" title="Code">💻</a></td>
      <td align="center" valign="top" width="14.28%"><a href="http://zhr.is"><img src="https://avatars.githubusercontent.com/u/148818634?v=4?s=100" width="100px;" alt="Chris Pineda"/><br /><sub><b>Chris Pineda</b></sub></a><br /><a href="https://github.com/CodeEditApp/CodeEdit/commits?author=zhrispineda" title="Code">💻</a></td>
    </tr>
  </tbody>
</table>

<!-- markdownlint-restore -->
<!-- prettier-ignore-end -->

<!-- ALL-CONTRIBUTORS-LIST:END -->

## License

Licensed under the [MIT license](https://github.com/CodeEditApp/CodeEdit/blob/main/LICENSE.md).

## Related Repositories

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/CodeEditApp/CodeEditKit">
        <img src="https://github.com/CodeEditApp/CodeEditKit/blob/main/.github/CodeEditKit-Icon-128@2x.png?raw=true" height="128">
      </a>
      <p>&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://github.com/CodeEditApp/CodeEditKit">CodeEditKit</a>&nbsp;&nbsp;&nbsp;&nbsp;</p>
    </td>
    <td align="center">
      <a href="https://github.com/CodeEditApp/CodeEditTextView">
        <img src="https://github.com/CodeEditApp/CodeEditTextView/blob/main/.github/CodeEditTextView-Icon-128@2x.png?raw=true" height="128">
      </a>
      <p><a href="https://github.com/CodeEditApp/CodeEditTextView">CodeEditTextView</a></p>
    </td>
    <td align="center">
      <a href="https://github.com/CodeEditApp/CodeEditSourceEditor">
        <img src="https://github.com/CodeEditApp/CodeEditTextView/blob/main/.github/CodeEditSourceEditor-Icon-128@2x.png?raw=true" height="128">
      </a>
      <p><a href="https://github.com/CodeEditApp/CodeEditSourceEditor">CodeEditSourceEditor</a></p>
    </td>
    <td align="center">
      <a href="https://github.com/CodeEditApp/CodeEditLanguages">
        <img src="https://github.com/CodeEditApp/CodeEditLanguages/blob/main/.github/CodeEditLanguages-Icon-128@2x.png?raw=true" height="128">
      </a>
      <p><a href="https://github.com/CodeEditApp/CodeEditLanguages">CodeEditLanguages</a></p>
    </td>
    <td align="center">
      <a href="https://github.com/CodeEditApp/CodeEditCLI">
        <img src="https://github.com/CodeEditApp/CodeEditCLI/blob/main/.github/CodeEditCLI-Icon-128@2x.png?raw=true" height="128">
      </a>
      <p>&nbsp;&nbsp;&nbsp;&nbsp;<a href="https://github.com/CodeEditApp/CodeEditCLI">CodeEditCLI</a>&nbsp;&nbsp;&nbsp;&nbsp;</p>
    </td>
  </tr>
</table>
