# StudyBro API

The REST API and Socket.IO server behind the StudyBro app, written with Express on top of PostgreSQL.

## Setup

Copy `.env.example` to `.env` and fill it in:

| Variable | Meaning |
|---|---|
| `PORT` | port the server listens on, 3000 if unset |
| `DB_HOST`, `DB_PORT`, `DB_NAME` | the PostgreSQL server and database |
| `DB_USER`, `DB_PASSWORD` | the database credentials |
| `JWT_SECRET` | secret used to sign and check login tokens |

Then install and start:

```bash
npm install
npm start
```

The connection to PostgreSQL uses SSL, and the table definitions are not included in this repository.

## Good to know

- `index.js` registers the routes and serves the Swagger documentation at `/api-docs`. `queries.js` holds the request handlers and every SQL statement, and `auth.js` is the middleware that checks the Bearer token.
- When an admin creates a public set, the server emits a `newPublicSet` event to all connected Socket.IO clients.
- Card images arrive as multipart uploads, are stored in the database and are sent back as base64.

The list of routes is in the README at the root of the repository.
