# tests
PathingTest.tscn sweeps 39 pellet drops across the tank and reports eaten/fails. Run headlessly with --fixed-fps 60. It forces hunger so movement and food reachability are tested independently of fullness.

MergeTest.gd and AlgaeTest.gd are headless SceneTree integration scripts. Run with --headless --path . --script res://tests/MergeTest.gd (or AlgaeTest.gd). Use a fresh XDG_DATA_HOME to isolate saves; never run these on a real player save. Merge covers fees, owned matching tiers, pause/away/max guards, UI, save migration, 4x payouts and offline tier math. Algae covers time growth, cap48, wall climb, food fading/no waste, maintenance pause/visit and offline ownership.
