# autoload
Global singletons, registered in Project Settings > Globals > Autoload in this order:
1. Events - signal bus only. Systems emit/connect here.
2. GameState - single source of truth for money.
3. SaveManager - version 1 JSON in user://save.json. Stores money, each fish's FishData resource path, fullness, position, and saved_at unix timestamp. No offline earnings yet.

Tank calls load_tank when Main starts. Missing, invalid, or unsupported saves fall back to default Goldy. Money changes queue one save after five seconds (further changes do not restart that timer). Pause-menu Quit to Title/Quit and window close save immediately, including while paused. Title screen never overwrites a save with an absent tank. Writes use a temporary file in user:// before replacing the save.

Tests must set SaveManager.enabled = false before adding Main to prevent reading or writing a player's save.

Net owns the optional WebSocket visiting session, guest attribution and snapshot visuals. SaveManager also persists player name, tank identity, and gift outbox/receipts. Single-player needs no relay. See docs/Visiting.md.

Sand Roomba upgrade: see res://scenes/feeder/README.md for recycling, persistence and offline earnings rules.
