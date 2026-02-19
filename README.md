# Planning Poker

A real-time planning poker app for Scrum story point estimation. No database required—all state lives in memory.

## How it works

1. **Create a room** — Enter your name and create a room. Share the link with your team.
2. **Join** — Others enter the room code and their display name to join.
3. **Vote** — Each participant selects a Fibonacci point (1, 2, 3, 5, 8, or 13) for the task being estimated.
4. **Reveal** — Once everyone has voted, the facilitator (room creator) can reveal the values.
5. **New round** — After revealing, the facilitator can start a new round to estimate another task.

## Running the app

```bash
bundle install
bin/rails server
```

Open http://localhost:3000

## Tech stack

- Rails 8 with Turbo and Stimulus
- Action Cable for real-time updates (WebSockets)
- In-memory storage via `RoomStore` (no database)

## Deployment notes

- **Single process**: The in-memory store works with a single Puma process. For multi-worker deployments, configure Redis for Action Cable and consider adding a shared store (e.g. Redis) for rooms.
- **Production**: Set `REDIS_URL` if using Redis for Action Cable in production.

## Tests

```bash
bin/rails test
```
