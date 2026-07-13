# =========================================================================
# LAB PYAPP — reference for the Nix dev → image → k8s pipeline
# =========================================================================
# This is the "real" instance of the pattern in templates/python/flake.nix.
# The lab's pyapp (Flask, requirements.txt = flask==3.0.3) is built into an
# OCI image by Nix and pushed to the local registry for k3s — REPLACING the
# old `docker save | sudo k3s ctr images import` + `imagePullPolicy: Never`
# workflow documented in the now-superseded Dockerfile.
#
# Dev → deploy loop:
#     just build && just push && just deploy
# k3s must be up (`sudo systemctl start k3s` — it is on-demand, not at boot);
# the registry auto-starts (labs/k8s-registry.nix).
# =========================================================================
{
  description = "k8s-telemetry lab pyapp — Nix-built image";

  inputs.nixpkgs.url = "nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};

      imageName = "localhost:5000/pyapp";   # keep in lockstep with justfile + manifests/70-pyapp.yaml
      imageTag  = "latest";
    in {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          # flask comes from nixpkgs (requirements.txt pins 3.0.3; nixpkgs may
          # ship a different patch — fine for a lab probe). gunicorn is ADDED
          # here as the prod server: the old Dockerfile ran Flask's dev
          # `app.run()`; gunicorn is the correct upgrade for a k8s Deployment.
          appPython = pkgs.python3.withPackages (p: [ p.flask p.gunicorn ]);

          # Bake app.py into /app so the image mirrors templates/python's
          # shape (WorkingDir=/app, module `app` at /app/app.py). The lab keeps
          # app.py at the dir root, so wrap the single file into a dir.
          appSource = pkgs.runCommand "pyapp-src" { } ''
            mkdir -p $out
            cp ${./app.py} $out/app.py
          '';
        in {
          default = self.packages.${system}.image;
          image = pkgs.dockerTools.buildImage {
            name = imageName;
            tag  = imageTag;
            # BOTH must be present: appPython carries the gunicorn+flask closure
            # (Cmd-string refs are NOT auto-scanned into the image).
            copyToRoot = [ appPython appSource ];
            config = {
              WorkingDir   = "/app";
              Cmd          = [ "${appPython}/bin/gunicorn" "app:app" "--bind" "0.0.0.0:8080" ];
              ExposedPorts = { "8080/tcp" = { }; };
            };
          };
        });

      # Minimal devShell (kubectl/skopeo/just are also global on this host).
      devShells = forAllSystems (system:
        let pkgs = pkgsFor system; in {
          default = pkgs.mkShell {
            packages = with pkgs; [ python3 uv just skopeo kubectl ];
          };
        });
    };
}
