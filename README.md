# Ractive Restaurant - Backend + Frontend bundle

## What's included
- frontend/index.html  (single-file frontend)
- backend/             (Express + MySQL API)
  - server.js
  - db.js
  - package.json
  - migrations/schema.sql (will be executed automatically by MySQL container)
  - Dockerfile
- docker-compose.yml   (runs MySQL and the Node app)
- .env.example

## Requirements (two options)
1. Docker & Docker Compose (recommended)
2. Node.js (v18+) and MySQL server locally

## Run with Docker (recommended)
1. Make sure Docker is installed.
2. From this folder (where `docker-compose.yml` is located) run:
   ```bash
   docker-compose up --build
   ```
3. The backend API will be available at: http://localhost:3000
   - GET /api/menu
   - POST /api/orders
   - GET /api/orders/active
4. Open frontend in browser: http://localhost:3000/  (the server serves frontend/index.html)

Notes:
- The MySQL container initializes the database using the SQL in `backend/migrations/schema.sql`.
- Default MySQL root password is `example_password` (change in docker-compose.yml and .env.example).

## Run locally without Docker
1. Install Node.js and MySQL.
2. Create a database and run the SQL in `backend/migrations/schema.sql`.
3. Copy `.env.example` to `.env` and set credentials.
4. In `backend/` run:
   ```bash
   npm install
   npm start
   ```
5. Visit http://localhost:3000

## Quick testing with curl
- Fetch menu:
  ```bash
  curl http://localhost:3000/api/menu
  ```
- Create order (example):
  ```bash
  curl -X POST http://localhost:3000/api/orders -H "Content-Type: application/json" -d '{
    "session_id":"S1",
    "table_id":1,
    "queue_number":"A01",
    "items":[
      {"menu_item_id":3,"customer_id":1,"quantity":1,"unit_price":180,"total_price":180}
    ]
  }'
  ```

