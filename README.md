<div align="center">

# NestZone

**Everything your household needs, in one calm place.**

Tasks, shopping, notes, recipes, movie nights, money and house problems for the people you live with. Beautifully native, instantly in sync.

![iOS](https://img.shields.io/badge/iOS-26-000000?logo=apple&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-F05138?logo=swift&logoColor=white)
![TCA](https://img.shields.io/badge/The_Composable_Architecture-1F6FEB)
![Backend](https://img.shields.io/badge/backend-Convex-EE342F)

</div>

---

## What it does

| | |
|---|---|
| **Today** | One home screen for the household, with a customizable set of sections and a dock for tonight's dinner. |
| **Lists** | Shared tasks, shopping and notes that update live for everyone. |
| **Plans** | A shared calendar, meal planning with recipes, and movie lists, plus a swipe game to settle "what should we watch". |
| **House** | Split bills and keep track of money owed, and log problems around the house until they are fixed. |
| **Messages** | A household chat, right next to the things you are talking about. |
| **Capture** | One field that files a line into the right place: say it once, it lands in tasks, shopping or notes. |
| **Inbox** | The bell: household activity and the app's changelog. |

Built with Liquid Glass surfaces, considered motion and a String Catalog for localization.

## Tech

- **Client:** SwiftUI and [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture). One module, four layers: App, Core, Design, Features. Features never reach into each other.
- **Backend:** self-hosted [Convex](https://convex.dev) (`backend/convex`), with typed per-domain clients on the app side.
- **Delivery:** Xcode Cloud builds on push to `stage`; `deploy.sh` ships backend, changelog and version together.

## Project layout

```
NestZone/            the app (App, Core, Design, Features, Resources)
backend/convex/      queries, mutations and actions
Docs/                plans, prototypes and handoff notes
ci_scripts/          Xcode Cloud post-clone hook
```

## Getting started

1. Open `NestZone.xcodeproj` in Xcode 26.
2. Let Swift Package Manager resolve, and trust the package macros when asked.
3. Point the app at a Convex deployment and run on an iOS 26 simulator or device.

See [CLAUDE.md](CLAUDE.md) for architecture and conventions, and [XCODE_CLOUD.md](XCODE_CLOUD.md) for CI.

---

<div align="center">Made by <a href="https://github.com/orion-supernova">Murat Can Koç</a></div>
