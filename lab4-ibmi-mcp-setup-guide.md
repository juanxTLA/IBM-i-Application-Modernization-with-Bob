# Lab 4: IBM i MCP Server - Local and Remote Deployment Guide (DRAFT, not fully tested)

## Overview

This lab demonstrates how to set up and use the IBM i MCP Server in two different deployment scenarios:

1. **Local MCP Server** - Running on your workstation (Windows/macOS/Linux)
2. **Remote MCP Server** - Running on IBM i itself

Both approaches enable AI agents (like Bob) to interact with IBM i databases, execute SQL queries, and access system services through the Model Context Protocol (MCP).

## Prerequisites

Before starting, ensure you have:

- ✅ Node.js 22 or higher installed on your development machine
- ✅ Access to an IBM i system with appropriate credentials
- ✅ Mapepire installed and running on IBM i (port 8076 by default)
- ✅ Bob installed
- ✅ Basic understanding of IBM i and SQL

### Verify Mapepire Installation

On IBM i, check if Mapepire is running:

```bash
sc check mapepire
# Should show "running"
```

If not installed, follow the [Setup Mapepire guide](https://ibm-d95bab6e.mintlify.app/setup-mapepire).

---

## Deployment Comparison

| Feature | Local MCP Server | Remote MCP Server (IBM i) |
|---------|------------------|---------------------------|
| **Location** | Runs on workstation | Runs on IBM i |
| **Transport** | Stdio (local process) | HTTP/HTTPS (network) |
| **Authentication** | Direct credentials in config | Token-based (IBM i auth) |
| **Network** | No network latency | Network latency present |
| **Security** | Credentials in local files | Encrypted token exchange |
| **Use Case** | Development, single user | Production, multi-user |
| **Setup Complexity** | Simple | Moderate |
| **Connection Pooling** | Single pool | Per-user pools |

---

## Part 1: Local MCP Server Setup

The local MCP server runs on your workstation and connects to IBM i via Mapepire. This is ideal for development and single-user scenarios.

### Step 1: Install the MCP Server

You don't need to install anything - we'll use `npx` to run the latest version:

```bash
# Verify it works
npx -y @ibm/ibmi-mcp-server@latest --help
```

### Step 2: Create Configuration Files

Create a project directory for your MCP configuration:

```bash
mkdir ibmi-mcp-local
cd ibmi-mcp-local
```

#### Create `.env` file

Create a `.env` file with your IBM i connection details:

```bash
cat > .env << 'EOF'
# IBM i DB2 for i Connection Settings
DB2i_HOST=your-ibmi-hostname.com
DB2i_USER=your-username
DB2i_PASS=your-password
DB2i_PORT=8076
DB2i_IGNORE_UNAUTHORIZED=true

# Server Configuration (not used for stdio, but required)
MCP_TRANSPORT_TYPE=stdio
EOF
```

**Important:** Replace the placeholder values with your actual IBM i credentials.

### Step 3: Create SQL Tools Configuration

Create a `tools` directory and a sample YAML configuration:

```bash
mkdir -p tools
```

Create `tools/ibmi-tools.yaml`:

```yaml
sources:
  ibmi-system:
    host: ${DB2i_HOST}
    user: ${DB2i_USER}
    password: ${DB2i_PASS}
    port: 8076
    ignore-unauthorized: true

tools:
  system_status:
    source: ibmi-system
    description: "Overall system performance statistics with CPU, memory, and I/O metrics"
    parameters: []
    statement: |
      SELECT * FROM TABLE(QSYS2.SYSTEM_STATUS_INFO())

  system_activity:
    source: ibmi-system
    description: "Current system activity information including active jobs and resource utilization"
    parameters: []
    statement: |
      SELECT * FROM TABLE(QSYS2.SYSTEM_ACTIVITY_INFO())

  list_tables:
    source: ibmi-system
    description: "List tables in a specific schema"
    parameters:
      - name: schema_name
        type: string
        description: "Schema name to list tables from"
        required: true
    statement: |
      SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE, 
             COALESCE(NUMBER_ROWS, 0) AS ROW_COUNT
      FROM QSYS2.SYSTABLES
      WHERE TABLE_SCHEMA = ?
      ORDER BY TABLE_NAME

toolsets:
  performance:
    tools:
      - system_status
      - system_activity
  
  database:
    tools:
      - list_tables
```

### Step 4: Configure Bob for Local MCP Server

Edit your Bob MCP configuration file. The location depends on your platform:

**macOS:**
```bash
code ~/Library/Application\ Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/cline_mcp_settings.json
```

**Windows:**
```powershell
code %APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\cline_mcp_settings.json
```

**Linux:**
```bash
code ~/.config/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/cline_mcp_settings.json
```

Add the IBM i MCP server configuration:

```json
{
  "mcpServers": {
    "ibmi-mcp-local": {
      "command": "npx",
      "args": [
        "-y",
        "@ibm/ibmi-mcp-server@latest",
        "--transport",
        "stdio",
        "--tools",
        "/absolute/path/to/ibmi-mcp-local/tools"
      ],
      "env": {
        "DB2i_HOST": "your-ibmi-hostname.com",
        "DB2i_USER": "your-username",
        "DB2i_PASS": "your-password",
        "DB2i_PORT": "8076",
        "DB2i_IGNORE_UNAUTHORIZED": "true",
        "MCP_TRANSPORT_TYPE": "stdio",
        "NODE_OPTIONS": "--no-deprecation"
      }
    }
  }
}
```

**Critical:** 
- Replace `/absolute/path/to/ibmi-mcp-local/tools` with the actual absolute path
- Replace credentials with your actual IBM i system details
- Use forward slashes even on Windows: `C:/Users/yourname/ibmi-mcp-local/tools`

### Step 5: Test Local MCP Server

1. **Restart Bob** to load the new MCP configuration
2. **Open Bob** 
3. **Check MCP Status** - Look for the MCP icon (plug symbol) in Bob
4. **List Tools** - Ask Bob: "What tools do you have available?"
5. **Test a Tool** - Ask Bob: "Show me the system status of my IBM i"

If configured correctly, Bob should list the IBM i MCP tools and execute them successfully.

### Local Setup Advantages

✅ **Simple Setup** - No server deployment needed  
✅ **No Network Latency** - Direct local process communication  
✅ **Easy Debugging** - Logs visible in Bob  
✅ **Quick Iteration** - Immediate config changes  

### Local Setup Limitations

⚠️ **Single User** - Credentials shared in config  
⚠️ **No Remote Access** - Only works on your machine  
⚠️ **Credential Storage** - Passwords in plain text locally  

---

## Part 2: Remote MCP Server Setup (IBM i)

The remote MCP server runs on IBM i itself and provides HTTP/HTTPS endpoints for AI agents to connect. This is ideal for production and multi-user environments.

### Architecture Overview

```
┌─────────────────┐         HTTPS          ┌──────────────────┐
│   Workstation   │ ◄──────────────────►   │   IBM i System   │
│                 │   Bearer Token Auth    │                  │
│  Bob            │                        │  MCP Server      │
│  AI Agent       │                        │  (Node.js)       │
└─────────────────┘                        │                  │
                                           │  Mapepire        │
                                           │  (Port 8076)     │
                                           │                  │
                                           │  Db2 for i       │
                                           └──────────────────┘
```

### Step 1: Install Node.js on IBM i

SSH into your IBM i system and install Node.js if not already present:

```bash
# Check if Node.js is installed
node --version

# If not installed, use yum to install
yum install nodejs18

# Verify installation
node --version  # Should show v18.x.x or higher
```

### Step 2: Clone MCP Server Repository on IBM i

```bash
# Create a directory for the MCP server
mkdir -p /home/YOURUSER/ibmi-mcp-server
cd /home/YOURUSER/ibmi-mcp-server

# Clone the repository
git clone https://github.com/IBM/ibmi-mcp-server.git .

# Install dependencies
npm install

# Build the project
npm run build
```

### Step 3: Generate RSA Encryption Keys

IBM i authentication uses RSA encryption to protect credentials during transmission:

```bash
# Create secrets directory
mkdir -p secrets

# Generate RSA private key (2048-bit)
openssl genpkey -algorithm RSA \
  -out secrets/private.pem \
  -pkeyopt rsa_keygen_bits:2048

# Extract public key
openssl rsa -pubout \
  -in secrets/private.pem \
  -out secrets/public.pem

# Set secure permissions
chmod 600 secrets/private.pem
chmod 644 secrets/public.pem
```

**Security Note:** The private key must be protected. Anyone with access to this file can decrypt client credentials.

### Step 4: Create Remote Configuration

Create `.env` file on IBM i:

```bash
cat > .env << 'EOF'
# Authentication Mode
MCP_AUTH_MODE=ibmi
IBMI_HTTP_AUTH_ENABLED=true

# Encryption Keys
IBMI_AUTH_KEY_ID=production
IBMI_AUTH_PRIVATE_KEY_PATH=secrets/private.pem
IBMI_AUTH_PUBLIC_KEY_PATH=secrets/public.pem

# IBM i Connection (host only - credentials come from tokens)
DB2i_HOST=localhost
DB2i_PORT=8076
DB2i_IGNORE_UNAUTHORIZED=true

# DO NOT include DB2i_USER or DB2i_PASS
# Token authentication provides user credentials

# Server Configuration
MCP_TRANSPORT_TYPE=http
MCP_HTTP_PORT=3010
MCP_LOG_LEVEL=info

# Security Settings (production)
IBMI_AUTH_ALLOW_HTTP=false
IBMI_AUTH_TOKEN_EXPIRY_SECONDS=3600
IBMI_AUTH_CLEANUP_INTERVAL_SECONDS=300
IBMI_AUTH_MAX_CONCURRENT_SESSIONS=100
EOF
```

**Important Notes:**
- `DB2i_HOST=localhost` because Mapepire is on the same system
- Do NOT include `DB2i_USER` or `DB2i_PASS` - tokens provide credentials
- Set `IBMI_AUTH_ALLOW_HTTP=false` for production (requires HTTPS)

### Step 5: Create Tools Configuration on IBM i

Create the same `tools/ibmi-tools.yaml` as in the local setup:

```bash
mkdir -p tools
```

Copy the YAML content from Part 1, Step 3 into `tools/ibmi-tools.yaml`.

### Step 6: Start the Remote MCP Server

```bash
# Set configuration file path
export MCP_SERVER_CONFIG=.env

# Start the server
npm run start:http -- --tools ./tools
```

You should see:

```
✓ IBM i HTTP authentication enabled
✓ Public key loaded from secrets/public.pem
✓ Private key loaded from secrets/private.pem
✓ Server ready!
  Transport: http
  Host: 0.0.0.0:3010
  Endpoint: http://your-ibmi-host:3010/mcp
  Auth: IBM i HTTP (key_id: production)
```

### Step 7: Test Authentication Endpoint

From your workstation, verify the public key endpoint:

```bash
curl http://your-ibmi-host:3010/api/v1/auth/public-key
```

Should return:

```json
{
  "keyId": "production",
  "publicKey": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhki..."
}
```

### Step 8: Get an Access Token

Use the helper script to obtain a Bearer token:

```bash
# On IBM i
cd /home/YOURUSER/ibmi-mcp-server

# Get token (replace with your credentials)
node get-access-token.js \
  --host localhost \
  --port 3010 \
  --user YOURUSER \
  --password YOURPASS \
  --verbose
```

The script will output:

```bash
# Copy and run this command:
export IBMI_MCP_ACCESS_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

Copy and run the export command on your workstation.

### Step 9: Configure Bob for Remote MCP Server

Edit your Bob MCP configuration file and add the remote server:

```json
{
  "mcpServers": {
    "ibmi-mcp-remote": {
      "url": "http://your-ibmi-host:3010/mcp",
      "transport": {
        "type": "http"
      },
      "headers": {
        "Authorization": "Bearer ${IBMI_MCP_ACCESS_TOKEN}"
      }
    }
  }
}
```

**For Production (HTTPS):**

```json
{
  "mcpServers": {
    "ibmi-mcp-remote": {
      "url": "https://your-ibmi-host:3010/mcp",
      "transport": {
        "type": "http"
      },
      "headers": {
        "Authorization": "Bearer ${IBMI_MCP_ACCESS_TOKEN}"
      }
    }
  }
}
```

### Step 10: Test Remote MCP Server

1. **Set Token** - Run the export command from Step 8 in your terminal
2. **Restart Bob IDE** to load the new configuration
3. **Open Bob** and verify the remote server appears
4. **Test Connection** - Ask Bob: "What tools are available on the remote server?"
5. **Execute Query** - Ask Bob: "Show me system activity from IBM i"

### Remote Setup Advantages

✅ **Multi-User** - Each user gets their own connection pool  
✅ **Token-Based Auth** - Secure, encrypted credential exchange  
✅ **Production Ready** - Designed for enterprise deployments  
✅ **Audit Trails** - Per-user tracking of operations  
✅ **Centralized** - Single server for multiple clients  

### Remote Setup Considerations

⚠️ **Network Latency** - HTTP requests over network  
⚠️ **Token Management** - Tokens expire (default 1 hour)  
⚠️ **HTTPS Required** - Production should use HTTPS  
⚠️ **Server Maintenance** - Need to keep server running  

---

## Part 3: Running Both Configurations

You can configure Bob to use both local and remote MCP servers simultaneously:

```json
{
  "mcpServers": {
    "ibmi-mcp-local": {
      "command": "npx",
      "args": [
        "-y",
        "@ibm/ibmi-mcp-server@latest",
        "--transport",
        "stdio",
        "--tools",
        "/absolute/path/to/tools"
      ],
      "env": {
        "DB2i_HOST": "dev-ibmi.company.com",
        "DB2i_USER": "DEVUSER",
        "DB2i_PASS": "devpass",
        "DB2i_PORT": "8076",
        "MCP_TRANSPORT_TYPE": "stdio"
      }
    },
    "ibmi-mcp-remote": {
      "url": "https://prod-ibmi.company.com:3010/mcp",
      "transport": {
        "type": "http"
      },
      "headers": {
        "Authorization": "Bearer ${IBMI_MCP_ACCESS_TOKEN}"
      }
    }
  }
}
```

This allows you to:
- Use local server for development/testing
- Use remote server for production queries
- Switch between environments easily

---

## Troubleshooting

### Local MCP Server Issues

**Server Not Appearing in Bob:**
- Verify JSON syntax in MCP settings file
- Check that `npx -y @ibm/ibmi-mcp-server@latest` works from terminal
- Ensure absolute paths are used for `--tools`
- Restart Bob completely

**Connection to IBM i Failed:**
- Test IBM i connectivity: `ping your-ibmi-host`
- Verify Mapepire is running: `sc check mapepire` (on IBM i)
- Check firewall allows port 8076
- Verify credentials are correct

**Tools Not Loading:**
- Verify tools path exists and is absolute
- Check YAML files are valid
- Ensure IBM i credentials are correct in `.env`

### Remote MCP Server Issues

**Authentication Failed:**
- Verify server is running: `curl http://your-ibmi-host:3010/api/v1/auth/public-key`
- Check token is valid: `echo $IBMI_MCP_ACCESS_TOKEN`
- Ensure token hasn't expired (default: 1 hour)
- Get a fresh token using `get-access-token.js`

**Server Won't Start:**
- Check Node.js version: `node --version` (must be 18+)
- Verify port 3010 is not in use: `netstat -an | grep 3010`
- Check `.env` file syntax
- Review server logs for errors

**HTTPS Certificate Issues:**
- For development, use `IBMI_AUTH_ALLOW_HTTP=true`
- For production, configure proper SSL certificates
- Check `DB2i_IGNORE_UNAUTHORIZED` setting

---

## Best Practices

### Development Environment
- ✅ Use **local MCP server** for rapid development
- ✅ Store credentials in `.env` files (add to `.gitignore`)
- ✅ Use `IBMI_AUTH_ALLOW_HTTP=true` for testing
- ✅ Keep tools in version control

### Production Environment
- ✅ Use **remote MCP server** on IBM i
- ✅ Enable HTTPS with valid certificates
- ✅ Set `IBMI_AUTH_ALLOW_HTTP=false`
- ✅ Use strong RSA keys (2048-bit minimum)
- ✅ Implement token rotation policies
- ✅ Monitor server logs and performance
- ✅ Set appropriate token expiry times
- ✅ Limit concurrent sessions

### Security
- 🔒 Never commit credentials to version control
- 🔒 Protect RSA private keys (chmod 600)
- 🔒 Use environment variables for sensitive data
- 🔒 Rotate tokens regularly
- 🔒 Use HTTPS in production
- 🔒 Implement proper IBM i user authorities
- 🔒 Monitor authentication logs

---

## Next Steps

1. **Explore Pre-Built Tools** - The MCP server includes many ready-made SQL tools for performance monitoring, security analysis, and system administration

2. **Create Custom Tools** - Build your own YAML tools for specific business queries

3. **Integrate with CI/CD** - Use the MCP server in automated workflows

4. **Scale to Production** - Deploy the remote server with proper monitoring and high availability

5. **Advanced Features** - Explore OpenTelemetry observability, OAuth integration, and multi-system configurations

---

## Additional Resources

- [IBM i MCP Server Documentation](https://ibm-d95bab6e.mintlify.app/quickstart)
- [SQL Tools Reference](https://ibm-d95bab6e.mintlify.app/sql-tools/built-in-tools)
- [Configuration Guide](https://ibm-d95bab6e.mintlify.app/configuration)
- [GitHub Repository](https://github.com/IBM/ibmi-mcp-server)
- [Mapepire Setup Guide](https://ibm-d95bab6e.mintlify.app/setup-mapepire)

---

## Summary

This lab covered two deployment approaches for the IBM i MCP Server:

| Aspect | Local (Stdio) | Remote (HTTP) |
|--------|---------------|---------------|
| **Best For** | Development, single user | Production, multi-user |
| **Setup** | Simple, quick | Moderate complexity |
| **Security** | Local credentials | Token-based, encrypted |
| **Performance** | No network latency | Network overhead |
| **Scalability** | Single user | Multiple concurrent users |

Choose the approach that best fits your use case, or use both for different environments!