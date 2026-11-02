# scenes/ui

TitleScreen is the project entry scene. Play opens scenes/main/Main.tscn; Quit closes the game.
HUD displays money from GameState and listens to Events.
PauseMenu lives under Main/UI, above the HUD. Escape (the pause input action) toggles it.
Its process mode is Always so Resume and Escape work while the tree is paused.
The full-screen Control blocks mouse input; Tank also rejects input while paused.
Quit to Title unpauses before changing scene. Returning to title does not reset GameState.
Use normal theme defaults for buttons and focus navigation.

Shop scans data/fish for FishData .tres resources, sorted by price. The bottom-right toggle opens a scrollable list with sprite, price, payout and affordability-aware Buy buttons.
Shop controls consume mouse clicks before Tank's unhandled input; its root ignores empty space.
It hides during pause and rejects purchases while paused. Purchase spends once and emits Events.fish_bought.
