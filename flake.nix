{
  description = "One-(digit-)click NixOS VM on macOS";

  inputs = {
    # TODO https://github.com/NixOS/nixpkgs/pull/372672
    # nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    nixpkgs.url = "github:phaer/nixpkgs?ref=vfkit-update";
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: inputs.blueprint { inherit inputs; };
}
