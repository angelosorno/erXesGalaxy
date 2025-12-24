# erXesGalaxy Script 🚀

## Erxes Next (OS Edition) Deployment 🚀

This repository hosts a customized, production-ready deployment of **Erxes Next OS**, the modular, microservice-based successor to Erxes v3. It creates a complete "Experience Operating System" (XOS) tailored for modular business growth.

Unlike the monolithic v3, this architecture is composed of independent, federated microservices (Plugins) orchestrated by a central Apollo Gateway.

## ✨ Key Features

- **Modular "OS" Architecture**: Runs distinct microservices for `sales`, `accounting`, `frontline`, and `automations`.
- **GraphQL Federation**: Uses Apollo Router/Gateway to unify all microservices into a single graph.
- **Pure Docker Stack**: No host dependencies beyond Docker. Compatible with macOS (Silicon/Intel) and Linux.
- **Hardened Security**: 
  - MongoDB Replica Set with Authentication (`keyFile` + Users).
  - Redis with Password Protection.
  - Internal Service network isolation.

## 📂 Architecture Overview

The stack is defined in `docker-compose.yml` using the **Erxes Next** Docker images:

### Core Layer (Kernel)
*   **`erxes-gateway`**: Apollo Router that merges all plugins into one API.
*   **`erxes-core-api`**: Handles Users, Permissions, and Authentication.
*   **`erxes-ui`**: The unified frontend dashboard.

### Plugin Layer (Apps)
These are independent microservices connected via Federation:
*   ✅ **Sales**: Deal pipelines and CRM.
*   ✅ **Frontline**: Shared team inbox and customer support.
*   ✅ **Accounting**: Invoicing, quotes, and financial tracking.
*   ✅ **Automations**: Workflow automation engine (triggers & actions).

### Infrastructure
*   **MongoDB 4.4**: Primary state store (Replica Set mode).
*   **Redis 7.2**: Caching and Pub/Sub for service discovery.

---

## 🚀 Quick Start

### 1. Prerequisites
*   Docker & Docker Compose installed.
*   Ports `80` (Gateway) and `3000` (UI) available.

### 2. Configure Environment
Ensure your `.env` file or `docker-compose.yml` variables are set (defaults are pre-configured for local dev):

```bash
# Core Security
cp env.example .env
```

### 3. Deploy
Use the provided script to handle the orchestration:

```bash
./install.sh
```

Or manually:

```bash
docker compose up -d
```

### 4. Access

| Service | URL | Credentials (Default) |
| :--- | :--- | :--- |
| **Dashboard** | `http://localhost:3000` | User: `test@mail.com` <br> Pass: `'4>X8+-=f2u}&>M` |
| **Gateway API** | `http://localhost` | (Internal API) |

## 🛠️ Management

### Adding New Plugins
To add a new Erxes module (e.g., `pos`, `integrations`):

1.  Add the service definition to `docker-compose.yml`:
    ```yaml
    plugin-newfeature-api:
      image: erxes/erxes-next-newfeature_api:latest
      # ... copy environment config from other plugins
    ```
2.  Update the `ENABLED_PLUGINS` variable in the `gateway` service:
    ```yaml
    ENABLED_PLUGINS: '...,newfeature'
    ```
3.  Restart the stack:
    ```bash
    docker compose up -d && docker restart erxes-gateway
    ```

### Troubleshooting
*   **Gateway Loops**: If the Gateway keeps "Waiting for plugin...", check the plugin logs to ensure it has successfully started and connected to Redis.
*   **CORS Issues**: Ensure `ALLOWED_ORIGINS` in `docker-compose.yml` matches your browser URL.

---

## 📜 Legacy Notes
*   This repo previously hosted Erxes v3. All legacy files have been removed in favor of the optimized Next architecture.