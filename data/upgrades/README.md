# data/upgrades
UpgradeData.gd defines an upgrade. One .tres per upgrade (bigger tank, auto feeder, better food...).
GameState tracks which ones are owned; effects are applied by whatever system they affect.

Sand Roomba upgrade: see res://scenes/feeder/README.md for recycling, persistence and offline earnings rules.

Roomba now cleans glass-edge algae, not fish waste. Algae grows independently every 12s (cap48); 3 patches make one half-value pellet. Landed food fades over its last 3 seconds, expires after20s, and never creates waste.
