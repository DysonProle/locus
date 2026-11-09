{
  description = "Locus on an exe.dev VM (Ubuntu + Nix + system-manager)";

  inputs = {
    locus.url = "github:maxiomattic/locus";
    # Not following locus's nixpkgs: a system-manager revision only works
    # with the nixpkgs it was developed against.
    system-manager.url = "github:numtide/system-manager";
  };

  outputs =
    { locus, system-manager, ... }:
    {
      systemConfigs.default = system-manager.lib.makeSystemConfig {
        modules = [
          locus.nixosModules.services
          # Locus's own Vere pin, whose kelvin matches the desk, rather than
          # system-manager's nixpkgs urbit.
          { locus.server.urbit.package = locus.packages.x86_64-linux.urbit; }
          ./host.nix
        ];
      };
    };
}
