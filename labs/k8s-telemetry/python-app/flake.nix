# =========================================================================
# LAB PYAPP — modern Nix dev -> image -> k8s pipeline (uv2nix)
# =========================================================================
# Migrated OFF the old pattern (nixpkgs python3.withPackages + a vestigial
# requirements.txt + a superseded Dockerfile) ONTO the current scaffold
# (templates/python): uv2nix builds the venv from uv.lock — the SINGLE source
# of truth for both the dev shell and the image. No more requirements.txt-vs-
# nixpkgs version drift.
#
# Flask + gunicorn (the lab stays Flask; the scaffold's default is FastAPI).
# Same deploy loop as before:
#     just build && just push && just deploy
# k3s is on-demand (sudo systemctl start k3s); the registry auto-starts
# (labs/k8s-registry.nix).
# =========================================================================
{
  description = "k8s-telemetry lab pyapp — uv2nix Nix-built image";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";

    # uv2nix: build the venv from uv.lock — single source of truth for the dev
    # shell AND the image. pyproject-build-systems supplies the PEP-517 build
    # backends uv2nix needs when building sdists.
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
    uv2nix.url = "github:pyproject-nix/uv2nix";
    uv2nix.inputs.pyproject-nix.follows = "pyproject-nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, uv2nix, pyproject-nix, pyproject-build-systems }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Lockstep with the justfile + ../manifests/70-pyapp.yaml.
      imageName = "localhost:5000/pyapp";
      imageTag  = "latest";

      perSystem = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib  = nixpkgs.lib;

          # Load pyproject.toml + uv.lock as a uv workspace; build an overlay
          # that supplies every dependency from the lock (wheels preferred).
          workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
          overlay   = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

          # Base Python set (pyproject.nix) + the uv2nix lock overlay + the
          # PEP-517 build-backend set (so sdist builds resolve their backend).
          pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
            python = pkgs.python3;
          }).overrideScope (lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            overlay
          ]);

          # ONE venv for both the image and the devShell — deps come from uv.lock.
          venv = pythonSet.mkVirtualEnv "pyapp-env" workspace.deps.default;
        in { inherit pkgs venv; };
    in {
      packages = forAllSystems (system:
        let
          ps   = perSystem system;
          pkgs = ps.pkgs;

          # Bake app/ into /app. A bare path in copyToRoot flattens to the image
          # root (-> /app.py, not /app/app.py), so wrap it in a runCommand that
          # emits an app/ subdir whose CONTENTS land at /app. -> image has
          # /app/app.py, so gunicorn `app:app` resolves module `app` at /app.
          appSource = pkgs.runCommand "app-src" { } ''
            mkdir -p $out/app
            cp -r ${./app}/. $out/app/
          '';

          # Non-root runtime (UID 1000) so the pod runs least-privilege. Provides
          # /etc/passwd + /etc/group; config.User runs the entrypoint as 1000:1000.
          nonRootUser = pkgs.runCommand "non-root-user" { } ''
            mkdir -p $out/etc
            printf 'root:x:0:0::/root:/bin/sh\nappuser:x:1000:1000::/app:/bin/sh\n' > $out/etc/passwd
            printf 'root:x:0:\nappuser:x:1000:\n'                                 > $out/etc/group
          '';

          # gunicorn needs a writable TMPDIR (it creates worker temp files).
          # Nix dockerTools images ship NO /tmp by default and the container runs
          # non-root (1000:1000), so bake a world-writable /tmp via runAsRoot.
          # (copyToRoot does NOT preserve the 1777 mode on world-writable dirs, and
          # fakeRootCommands is streamLayeredImage-only, not buildImage — runAsRoot
          # is the correct mechanism here. It uses a one-time, cached qemu VM; if
          # build speed ever matters, switch to streamLayeredImage + fakeRootCommands.)
          # Works in both `just test` and the k3s pod. (FastAPI/uvicorn doesn't need
          # this — uvicorn creates no temp files — gunicorn does.)
        in {
          default = self.packages.${system}.image;
          image = pkgs.dockerTools.buildImage {
            name = imageName;
            tag  = imageTag;
            copyToRoot = [ ps.venv appSource nonRootUser ];
            runAsRoot = ''
              ${pkgs.coreutils}/bin/mkdir -p /tmp
              ${pkgs.coreutils}/bin/chmod 1777 /tmp
            '';
            config = {
              User       = "1000:1000";
              WorkingDir = "/app";
              # Same entry point local dev runs (justfile `run`): gunicorn app:app.
              Cmd        = [ "${ps.venv}/bin/gunicorn" "app:app" "--bind" "0.0.0.0:8080" ];
              ExposedPorts = { "8080/tcp" = { }; };
            };
          };
        });

      devShells = forAllSystems (system:
        let
          ps   = perSystem system;
          pkgs = ps.pkgs;
        in {
          default = pkgs.mkShell {
            packages = [
              ps.venv            # flask + gunicorn from uv.lock — SAME source as the image
              pkgs.uv            # `uv lock` to refresh deps
              pkgs.ruff pkgs.mypy
              pkgs.just pkgs.skopeo pkgs.kubectl
            ];
            shellHook = ''
              echo ""
              echo "  > pyapp devshell active  [flask + gunicorn . uv2nix]"
              echo "      venv   $(readlink -f ${ps.venv})"
              echo "      image  ${imageName}:${imageTag}"
              echo "      deps   edit pyproject.toml -> \`uv lock\` -> rebuild"
              echo "      run    just run    . deploy  just deploy"
              echo ""
              # Undo nixpkgs PYTHONPATH propagation so the venv's site-packages win.
              unset PYTHONPATH
            '';
          };
        });
    };
}
