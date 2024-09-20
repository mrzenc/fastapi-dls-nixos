{
  description = "NixOS module for fastapi-dls";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs }:
  let
    # https://ayats.org/blog/no-flake-utils#do-we-really-need-flake-utils
    forAllSystems = function:
      nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ] (system: function nixpkgs.legacyPackages.${system});
  in
  {
    packages = forAllSystems (pkgs: {
      default = pkgs.callPackage ./package.nix {};
    });
    nixosModules.default = import ./default.nix { inherit self; };
  };
}
