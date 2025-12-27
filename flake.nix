{
  description = "CUPS driver for ZJ-58/ZJ-80 thermal receipt printers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = self.packages.${system}.zj-58;

          zj-58 = pkgs.stdenv.mkDerivation {
            pname = "cups-zj-58";
            version = "2.0.0";

            src = ./.;

            nativeBuildInputs = with pkgs; [
              cmake
              cups # for ppdc
            ];

            buildInputs = with pkgs; [
              cups
              cups.dev
            ];

            # CUPS paths for NixOS
            cmakeFlags = [
              "-DCMAKE_INSTALL_PREFIX=${placeholder "out"}"
              "-DPPDC=${pkgs.cups}/bin/ppdc"
              # CMakeLists.txt uses version 3.0, modern cmake requires >= 3.5
              "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
            ];

            # Override the install phase to use proper Nix paths
            installPhase = ''
              runHook preInstall

              # Install the filter binary
              install -Dm755 rastertozj $out/lib/cups/filter/rastertozj

              # Install PPD files
              install -Dm644 ppd/zj58.ppd $out/share/cups/model/zjiang/zj58.ppd
              install -Dm644 ppd/zj80.ppd $out/share/cups/model/zjiang/zj80.ppd
              install -Dm644 ppd/xp58.ppd $out/share/cups/model/zjiang/xp58.ppd
              install -Dm644 ppd/tm20.ppd $out/share/cups/model/zjiang/tm20.ppd

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "CUPS filter (driver) for thermal receipt printers (ZJ-58, ZJ-80, XP-58, TM-T20)";
              homepage = "https://github.com/klirichek/zj-58";
              license = licenses.mit;
              platforms = platforms.unix;
              maintainers = [ ];
            };
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cmake
            cups
            cups.dev
          ];
        };
      }
    ) // {
      # NixOS module for easy printer setup
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.printing.drivers.zj-58;
          zj-58-pkg = self.packages.${pkgs.system}.zj-58;
        in
        {
          options.services.printing.drivers.zj-58 = {
            enable = lib.mkEnableOption "ZJ-58/ZJ-80 thermal printer driver";
          };

          config = lib.mkIf cfg.enable {
            services.printing = {
              enable = true;
              drivers = [ zj-58-pkg ];
            };
          };
        };

      # Overlay for use with nixpkgs
      overlays.default = final: prev: {
        cups-zj-58 = self.packages.${prev.system}.zj-58;
      };
    };
}

