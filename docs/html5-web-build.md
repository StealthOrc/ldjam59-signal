# HTML5 Web Build Notes

## Short answer

Yes, this game can plausibly target the web, but the path is not "desktop build script plus one extra flag."

There is now a concrete packager in this repo:

- [build-web.ps1](/C:/Users/nitra/.codex/worktrees/7fb4/ldjam59-out-of-signal/build-web.ps1:1)

It builds an uploadable HTML5 folder and ZIP using the standalone `love.js` player.

The most realistic route today is to package the game as a `.love` file and run it with the standalone `love.js` player from 2dengine, which documents support for LÖVE `11.5` and can load `.love` files directly:

- https://2dengine.com/doc/lovejs.html
- https://github.com/2dengine/love.js

The old Tanner Rogalsky `love.js` repo is archived and unmaintained:

- https://github.com/TannerRogalsky/love.js

## What looks good already

- The project is explicitly pinned to LÖVE `11.5` in [conf.lua](/E:/Dev/Projects/ldjam59-out-of-signal/conf.lua:3).
- Rendering is mostly immediate-mode `love.graphics` work and PNG assets, which is a much better fit for `love.js` than native extensions.
- Save data should have a reasonable browser story because `love.js` stores local data in IndexedDB, and this code already uses `love.filesystem` for profile/map/score persistence.

## The main blockers in this codebase

### 1. Desktop-only HTTP stack

The current network layer is built around a Windows-native `https.dll` module with LuaSocket/LuaSec fallbacks:

- [src/game/network/http_transport.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/network/http_transport.lua:15)
- [src/game/network/http_transport.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/network/http_transport.lua:174)
- [src/game/network/http_transport.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/network/http_transport.lua:190)
- [src/game/util/native_loader.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/util/native_loader.lua:3)
- [src/game/util/native_loader.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/util/native_loader.lua:4)
- [src/game/util/native_loader.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/util/native_loader.lua:55)

That is a direct mismatch with the current `love.js` docs, which call out problems with LuaSocket and instead provide an asynchronous `fetch.lua` module for HTTP/HTTPS:

- https://2dengine.com/doc/lovejs.html

Practical implication:

- The leaderboard/upload/favorite flow should be expected to need a web-specific transport adapter.
- The cleanest design is probably `http_transport_desktop.lua` plus `http_transport_web.lua`, selected by capability detection.

### 2. Background worker thread for leaderboard fetches

The game currently creates a worker thread and uses thread channels:

- [src/game/app/game_runtime.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/app/game_runtime.lua:485)
- [src/game/app/game_runtime.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/app/game_runtime.lua:486)
- [src/game/app/game_remote_services.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/app/game_remote_services.lua:753)
- [src/game/network/leaderboard_fetch_thread.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/network/leaderboard_fetch_thread.lua:22)

The official LÖVE wiki still warns that web distribution does not support threads:

- https://love2d.org/wiki/Game_Distribution

I could not find current 2dengine documentation explicitly promising `love.thread` support, so the safest assumption is that this is still high risk for the web build.

Practical implication:

- The leaderboard flow should be refactored for the browser to use async requests on the main thread.
- Even if thread support exists in some setups, removing that dependency will make the port much more robust.

### 3. Runtime config is loaded from `.env` / process environment

The online config loader expects either `.env` files or process environment variables:

- [.env.example](/E:/Dev/Projects/ldjam59-out-of-signal/.env.example:1)
- [src/game/network/env_loader.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/network/env_loader.lua:255)
- [src/game/network/env_loader.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/network/env_loader.lua:266)
- [src/game/network/env_loader.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/network/env_loader.lua:270)

That model is awkward for static browser hosting.

Practical implication:

- For web, API configuration should come from a small generated Lua/JSON file, a JS bootstrap value, or a public config endpoint.
- Secret API keys must not be shipped to the browser unless the backend is intentionally using a public client key model.

### 4. Desktop file-manager affordances do not translate to the browser

The editor tries to open the user maps folder via `love.system.openURL(file://...)`:

- [src/game/editor/map_editor_panels.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/editor/map_editor_panels.lua:920)
- [src/game/editor/map_editor_panels.lua](/E:/Dev/Projects/ldjam59-out-of-signal/src/game/editor/map_editor_panels.lua:927)

In a browser build, there is no real "open my save folder on disk" equivalent.

Practical implication:

- This should become a no-op or a different UX on web, likely "export map" / "download map" instead.

## Browser/platform constraints worth planning around

The current `love.js` docs also call out:

- Audio restrictions before a user gesture
- Fullscreen restrictions before a user gesture
- LuaSocket limitations
- IndexedDB-backed local storage

Source:

- https://2dengine.com/doc/lovejs.html

For this repo, the good news is that a quick asset scan did not turn up packaged music/sfx/font/shader files, so the first porting pass looks more network-bound than media-bound.

## Recommended first implementation plan

### Phase 1: Make the game web-safe without changing gameplay

1. Add a tiny platform/capability module, for example `src/game/platform.lua`.
2. Teach the game to detect a web runtime and branch on capabilities instead of OS names.
3. Split the HTTP layer into desktop and web implementations.
4. Replace the leaderboard worker thread with a main-thread async flow on web.
5. Disable or replace "open folder" style actions in the web UI.

### Phase 2: Add a repeatable web packaging step

1. Produce `out-of-signal.love` from the project root.
2. Stage a `web-dist/` directory containing:
   - the `love.js` player files
   - `out-of-signal.love`
   - an `index.html` / embed page
3. Host that directory on a server that can set:
   - `Cross-Origin-Opener-Policy: same-origin`
   - `Cross-Origin-Embedder-Policy: require-corp`
   - a CSP that allows the documented WASM behavior

Per the `love.js` docs, this does not work by opening `index.html` directly from disk.

## Recommended architecture change

If we want this port to stay healthy, the networking boundary should become explicit:

- `network/http_transport_desktop.lua`
- `network/http_transport_web.lua`
- `network/http_transport.lua` as a thin selector

That gives us one place to map:

- native `https.dll` / LuaSocket on desktop
- `fetch.lua` callbacks on web

The same pattern likely applies to:

- threaded leaderboard work
- file/folder affordances
- any future clipboard/fullscreen niceties

## Verdict

The game is web-portable, but not web-ready yet.

The rendering/input/storage side looks encouraging. The real work is in removing desktop assumptions from:

- HTTP transport
- threaded leaderboard fetching
- environment-based runtime config
- file-manager style editor actions

If those are refactored cleanly, a browser build looks very achievable.
