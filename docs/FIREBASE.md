# Firebase MCP Reference

Firebase provides Google Cloud-based backend services including hosting, database, and functions.

## Trigger Commands

| Command | Action | Details |
|---------|--------|---------|
| `firebase status` | LIST_PROJECTS | List Firebase projects |
| `deploy firebase` | DEPLOY | Deploy to Firebase |
| `firebase logs` | LOGS | View Firebase logs |
| `firestore query` | QUERY | Query Firestore |
| `firebase init` | INIT | Initialize Firebase in project |
| `firebase apps` | LIST_APPS | List Firebase apps |

## Available Tools

### Authentication

#### mcp__firebase__firebase_login
Sign into Firebase CLI.

#### mcp__firebase__firebase_logout
Sign out of Firebase CLI.

#### mcp__firebase__firebase_get_me
Get authenticated user details.

### Environment

#### mcp__firebase__firebase_get_environment
Get current Firebase configuration.

**Returns:**
- Authenticated user
- Project directory
- Active project
- Available projects

#### mcp__firebase__firebase_update_environment
Update environment configuration.

**Parameters:**
- `project_dir`: Change project directory
- `active_project`: Change active project
- `active_user_account`: Change authenticated user

### Projects

#### mcp__firebase__firebase_list_projects
List all accessible Firebase projects.

#### mcp__firebase__firebase_get_project
Get details about active project.

#### mcp__firebase__firebase_create_project
Create a new Firebase project.

**Parameters:**
- `project_id`: Project ID
- `display_name`: User-friendly name

### Apps

#### mcp__firebase__firebase_list_apps
List apps in current project.

**Parameters:**
- `platform`: ios, android, web, or all

#### mcp__firebase__firebase_create_app
Create a new Firebase app.

**Parameters:**
- `platform`: web, ios, or android
- `display_name`: App name
- `ios_config` or `android_config`: Platform-specific config

#### mcp__firebase__firebase_get_sdk_config
Get SDK configuration for an app.

### Initialization

#### mcp__firebase__firebase_init
Initialize Firebase services in project directory.

**Supported Features:**
- `firestore`: Cloud Firestore
- `database`: Realtime Database
- `dataconnect`: Data Connect with Cloud SQL
- `hosting`: Firebase Hosting
- `storage`: Firebase Storage
- `ailogic`: Firebase AI Logic

### Security Rules

#### mcp__firebase__firebase_get_security_rules
Get security rules for a service.

**Parameters:**
- `type`: firestore, rtdb, or storage

### Resources

#### mcp__firebase__firebase_read_resources
Read Firebase resources.

## Best Practices

1. **Check environment first** before operations
2. **Use project aliases** for easier switching
3. **Review security rules** before deploying
4. **Use hosting preview channels** for testing
5. **Deploy incrementally** - not everything at once
