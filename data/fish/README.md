# data/fish
FishData.gd defines species. Add a .tres in this folder to include it in the shop automatically.
Goldy costs $25 and pays $5 per pellet; Bluefin costs $60 and pays $10; Rosie costs $300 and pays $25.
The starting Goldy is free. All use 0.02 fullness loss/sec and 0.25 nutrition/pellet, roughly one pellet per 12.5 seconds once settled. Bluefin takes roughly 2-3 minutes with Goldy; Rosie is a longer goal, accelerated by more fish.
Prices, payouts, hunger and sprites belong in resources, not UI code.

FishTier.gd centralizes instance tier math and sprite styling. Tier 0/Golden/Shiny/Royal (0..3) pays base times 1/4/16/64. Tier lives on Fish, not species resources.
