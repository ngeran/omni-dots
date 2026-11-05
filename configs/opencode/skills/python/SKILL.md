---
name: python
description: Python apps with FastAPI, uv, pyproject, PyEZ/network automation. Load for .py files, pyproject.toml, uv.lock, or pytest failures.
---

## Rules
- `pyproject.toml` and `uv.lock` are the single dependency source. Never add
  `requirements.txt`.
- Type-hint everything. Verify with `ruff check`, `mypy` or `pyright`, and
  `pytest`.
- FastAPI: Pydantic v2 models, async only where I/O is real, health endpoint at
  `/healthz`.
- PyEZ calls block: wrap in a threadpool or run via `run_in_executor` inside
  async code.
- Containers run non-root.
