# ============================================================================
# ⚠️  SUPERSEDED — kept only as a reference for a non-Nix (plain docker) build.
# ============================================================================
# The lab pyapp image is now built by NIX: see ./flake.nix (packages.image,
# pkgs.dockerTools.buildImage). The deploy path is `just build && just push &&
# just deploy` (skopeo → localhost:5000/pyapp:latest). This Dockerfile is NOT
# on that path. Use it only if you need a classic pip-based image outside Nix.
# ----------------------------------------------------------------------------
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

EXPOSE 8080
CMD ["python", "app.py"]
