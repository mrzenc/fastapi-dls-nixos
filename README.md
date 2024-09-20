# NixOS module for [fastapi-dls](https://git.collinwebdesigns.de/oscar.krause/fastapi-dls)

## Installation

### With Flakes

flake.nix:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/some-channel";
    # add new input
    fastapi-dls-nixos = {
      url = "github:mrzenc/fastapi-dls-nixos";
      # use nixpkgs provided by system to save some space
      # do not use this in case of problems
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ... other inputs ...
  };
  outputs =
    nixosConfigurations.mrzenc = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        # add module
        fastapi-dls-nixos.nixosModules.default
      ];
    };
  };
}
```

### Without Flakes

configuration.nix:

```nix
{
  imports = [
    (import (pkgs.fetchFromGithub {
      owner = "mrzenc";
      repo = "fastapi-dls-nixos";
      rev = "1.3.12";
      sha256 = ""; # leave empty to error out the correct hash
    }) {}) # don't forget about {}
    # ...
  ];

  config = [ /* ... */ ];
}
```

## Configuration

```nix
services.fastapi-dls = {
  enable = true;

  # Options.
  # The comments to the right of the options are the environment variable that they set.
  # The values set in this example are the defaults. All possible options are listed here:
  # https://git.collinwebdesigns.de/oscar.krause/fastapi-dls#configuration
  debug = false;              # DEBUG
  listen.ip = "localhost";    # DLS_URL
  listen.port = 443;          # DLS_PORT
  authTokenExpire = 1;        # TOKEN_EXPIRE_DAYS
  lease.expire = 90;          # LEASE_EXPIRE_DAYS
  lease.renewalPeriod = 0.15; # LEASE_RENEWAL_PERIOD
  # Additional options (for example { INSTANCE_KEY_RSA = "..."; })
  extraOptions = {}
  # Custom timezone in format "America/Montreal", null will default to system timezone
  # See https://en.wikipedia.org/wiki/List_of_tz_database_time_zones#List for possible values
  timezone = null;
};
```
