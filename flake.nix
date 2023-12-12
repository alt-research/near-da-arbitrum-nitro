{
  description = "Development nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/23.05";
    unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, unstable, flake-utils, rust-overlay, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ 
          (import rust-overlay) 
       ];
        pkgs = import nixpkgs { inherit system overlays; };
        pkgs-unstable = import unstable { inherit system overlays; };
        rustVersion = (pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml);
        rustPlatform = pkgs.makeRustPlatform {
          cargo = rustVersion;
          rustc = rustVersion;
        };
      in {
        #stdenv = pkgs.clangStdenv;
        devShell = pkgs.mkShell {
          LIBCLANG_PATH = pkgs.libclang.lib + "/lib/";
          NIXPKGS_ALLOW_INSECURE=1;
          LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/:/usr/local/lib";

          # TODO: Fix this in this flake
          # cp -r /nix/store/6cxi0nn9jbwjf21smbx11znw3gc9cjb8-emscripten-3.1.47/share/emscripten/cache ~/.emscripten_cache
          # chmod u+rwX -R ~/.emscripten_cache
          EM_CACHE="~/.emscripten_cache";


          nativeBuildInputs = with pkgs; [
            bashInteractive
            emscripten
            taplo
            cmake
            openssl
            pkg-config
            pkgs-unstable.nodejs
            pkgs-unstable.yarn
            # clang
            llvmPackages_12.bintools
            llvmPackages_12.libclang
            protobuf
            rust-cbindgen
            
            # Should be go 1.19
            go
			      govendor
            gopls
            python3Full

          ];
          buildInputs = with pkgs; [
              (rustVersion.override { extensions = [ "rust-src" ]; })
          ];
          permittedInsecurePackages = [
          ];

        };
  });
}
