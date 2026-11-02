Web publishing uses Godot 4.7.1 and its matching Web export templates. The Web preset uses the Compatibility renderer without threads or extensions. Browser progress lives in that browser's local storage, separately from desktop saves.

Run scripts/deploy_web.sh from a machine with Godot, rsync and SSH access. Set GODOT, SSH_KEY, DEPLOY_HOST or DEPLOY_DIR when needed. Generated exports go into a temporary folder outside the collaborative project and never enter Backstitch history.

The current site is https://fish.40-160-53-64.sslip.io/ and multiplayer connects through wss://fish.40-160-53-64.sslip.io/relay on both desktop and web. TLS terminates at the existing Traefik instance; the isolated fishingidle nginx container serves the export and proxies the existing relay. Hosting config lives in /srv/fishingidle on the dedicated server, with automatic restart and certificate renewal. Existing sites and the relay's original port are unchanged.

To update only the game, run the deployment script. It imports assets, exports Web, uploads the build, and checks relay health. Close/reopen the game after deployment to load the new version. The site revalidates files instead of keeping a stale offline cache.
