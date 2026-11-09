# Locus on an exe.dev VM

The clan server's services (ship, gateway, desk deploy) on an
[exe.dev](https://exe.dev) VM, which runs Ubuntu on a disk Locus does not
own. [system-manager](https://github.com/numtide/system-manager) applies
`nixosModules.services` to the VM's own systemd. Nothing is formatted.

Differences from the NixOS server (`docs/install.html`):

- No ZFS (`locus.server.zfs.enable = false`). The pier is a plain directory,
  `/var/lib/urbit/pier/ship`, and desk deploys take no snapshots. exe.dev's
  own disk backups are the only safety net.
- Eyre listens on `127.0.0.1:8080` only. The gateway on port 8090 is the one
  way in, through exe.dev's HTTPS proxy, which is private by default: only
  exe.dev users with access to the VM can open it.
- Firewall options are ignored (system-manager warns about ports 8080 and
  8090). exe.dev does not expose VM ports except through its proxy.
- system-manager creates the `urbit` user with userborn, which edits
  `/etc/passwd` in mutable mode and keeps the existing users.

## Steps

1. Create a VM with at least 4 GB of RAM. The ship alone takes 2 GiB, and
   the first activation compiles the gateway and the browser app from
   source. See `ssh exe.dev help` for creating and resizing VMs.
2. On the VM, install Nix as system-manager's README describes (multi-user,
   flakes enabled).
3. Make sure the host has `rsync` and `sudo` in `/usr/bin`. `desk-deploy.sh`
   runs `sudo rsync`, and Ubuntu's sudo resets PATH:

   ```sh
   sudo apt-get install -y rsync
   ```

4. Create the host flake:

   ```sh
   nix flake new -t github:maxiomattic/locus#exe-dev locus-exedev
   cd locus-exedev
   ```

   To run a branch or fork, change `locus.url` in `flake.nix`.
5. Apply it:

   ```sh
   nix run github:numtide/system-manager -- switch --flake . --sudo
   ```

   If the desk deploy takes longer than 30 seconds (the first one always
   does), the switch ends with "Timeout waiting for systemd jobs". That is
   system-manager giving up the wait, not the deploy failing: `locus-desk`
   keeps running.

6. Follow the first boot. A new comet syncs and then compiles every agent,
   which can take 5 to 30 minutes:

   ```sh
   journalctl -fu urbit -u locus-desk
   ```

7. Get the login code once `locus-desk` has finished:

   ```sh
   sudo /run/system-manager/sw/bin/urbit-code
   ```

8. Point exe.dev's proxy at the gateway and open the app:

   ```sh
   ssh exe.dev share port <vm> 8090
   ```

   Then open `https://<vm>.exe.xyz/app/`. Do not make the proxy public.

To remove the services, run `system-manager deactivate` (as root). The pier
in `/var/lib/urbit/pier` and the file bytes stay. The gateway runs with
`DynamicUser`, so the bytes are in `/var/lib/private/locus/files`.
