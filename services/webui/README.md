# OCS_LocalLLM_UI (integrated into mac-llm-cluster)

This folder contains the Local Web UI that was added into the cluster repository.

What I added:

- `Dockerfile` — multi-stage build that compiles the frontend and serves with `nginx`.
- `docker-compose.yml` — service `webui` that maps host port `3000` to container `80`.
- `scripts/webui/deploy_webui.sh` — bash script to build and deploy via `docker compose`.
- `scripts/webui/deploy_webui.ps1` — PowerShell variant for Windows.

Quick deploy (from repo root):

```bash
# Linux / macOS
./scripts/webui/deploy_webui.sh

# Windows PowerShell
.\scripts\webui\deploy_webui.ps1
```

Notes:

- `config/nginx/conf.d/webui.conf` already proxies `https://llm-01.local` -> `http://localhost:3000`. When the container is running and maps host port 3000, Nginx will forward requests to the webui.
- I did not run Docker here; run the deploy script on a machine with Docker and Compose available.

If you want, I can also:

- Add the webui service to any central orchestration you use for the cluster, or
- Create an alternative static-hosting setup (system service) instead of Docker.

