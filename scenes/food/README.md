# scenes/food`nFoodPellet.tscn sinks to the floor, can be claimed by one fish, dissolves 20s after landing. payout_mult is for the autofeeder later.`n
Sand Roomba upgrade: see res://scenes/feeder/README.md for recycling, persistence and offline earnings rules.

Roomba now cleans glass-edge algae, not fish waste. Algae grows independently every 12s (cap48); 3 patches make one half-value pellet. Landed food fades over its last 3 seconds, expires after20s, and never creates waste.
