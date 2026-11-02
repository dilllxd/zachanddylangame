# scenes/ui

TitleScreen is the project entry scene. Play opens scenes/main/Main.tscn; Quit closes the game.
HUD displays money from GameState and listens to Events.
PauseMenu lives under Main/UI, above the HUD. Escape (the pause input action) toggles it.
Its process mode is Always so Resume and Escape work while the tree is paused.
The full-screen Control blocks mouse input; Tank also rejects input while paused.
Quit to Title unpauses before changing scene. Returning to title does not reset GameState.
Use normal theme defaults for buttons and focus navigation.
