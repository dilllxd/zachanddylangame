# Autoloads

Events is the signal bus. GameState holds money, upgrades, identity and offline earnings. SaveManager stores validated version-1 records with stable fish IDs, tiers, fullness, positions, saved_at and server_revision. Writes atomically replace the local cache. Account owns HTTPS sessions, account-isolated caches and newest-save cloud sync. Net owns authenticated WSS public tank discovery, host simulation and server-validated gifts. See docs/Accounts.md and docs/Visiting.md.

Money changes coalesce into a five-second save. Shop/merge/gifts and quit/title transitions save immediately. No tank means no overwrite. Offline roomba income caps at eight hours. Tests may disable SaveManager before adding Main.
