import Fastify, { type FastifyInstance } from "fastify";

export interface BuildServerOptions {
  /** Fastify request/error logging. Disabled by tests to keep output readable. */
  logger?: boolean;
  /**
   * State for this server instance. Defaults to fresh deterministic fixtures;
   * tests inject a state to reach match statuses the public workflow cannot
   * produce. Omitted, every call still owns brand-new seed state.
   */
  initialState?: SeedState;
}

export interface Event {
  id: string;
  name: string;
  game: string;
  venue: string;
  startsAt: string;
  format: string;
  registrationStatus: string;
  checkedIn: boolean;
  checkedInAt: string | null;
  stations: string[];
  squadId: string | null;
  matchId: string | null;
}

export interface Player {
  id: string;
  handle: string;
  role: string | null;
  isCaptain: boolean;
  isReady: boolean;
  isCurrentUser: boolean;
}

export interface Squad {
  id: string;
  name: string;
  players: Player[];
}

export type MatchStatus = "scheduled" | "ready" | "in_progress" | "complete";

export interface Match {
  id: string;
  eventId: string;
  squadId: string;
  round: string;
  opponent: string;
  scheduledAt: string;
  format: string;
  status: MatchStatus;
  stations: string[];
  readyCount: number;
  teamSize: number;
}

/** In-memory state owned by a single server instance. */
export interface SeedState {
  events: Event[];
  squads: Squad[];
  matches: Match[];
}

/** Station assignment committed to the event and its match by check-in. */
const STATION_ASSIGNMENT = ["B11", "B12", "B13", "B14", "B15"];

const NOT_FOUND_BODY = {
  error: "NOT_FOUND",
  message: "The requested resource was not found.",
};

const CHECK_IN_REQUIRED_BODY = {
  error: "CHECK_IN_REQUIRED",
  message: "Check in before marking ready.",
};

const MATCH_LOCKED_BODY = {
  error: "MATCH_LOCKED",
  message: "Readiness is closed for this match.",
};

const INTERNAL_ERROR_BODY = {
  error: "INTERNAL_ERROR",
  message: "Something went wrong.",
};

/**
 * Builds fresh, deterministic demo fixtures. Every call returns new objects so
 * server instances never share state.
 */
export function createSeedState(): SeedState {
  return {
    events: [
      {
        id: "event-valorant-friday-lan",
        name: "Valorant Friday LAN",
        game: "Valorant",
        venue: "Nexus Box Hill",
        startsAt: "2026-09-18T19:00:00+10:00",
        format: "5v5 • BO1",
        registrationStatus: "open",
        checkedIn: false,
        checkedInAt: null,
        stations: [],
        squadId: "squad-five-stack",
        matchId: "match-round-2",
      },
      {
        id: "event-melbourne-rift-cup",
        name: "Melbourne Rift Cup",
        game: "League of Legends",
        venue: "Southern Cross Gaming Hall",
        startsAt: "2026-09-19T13:00:00+10:00",
        format: "5v5 • BO1",
        registrationStatus: "open",
        checkedIn: false,
        checkedInAt: null,
        stations: [],
        squadId: null,
        matchId: null,
      },
      {
        id: "event-cs2-saturday-clash",
        name: "CS2 Saturday Clash",
        game: "Counter-Strike 2",
        venue: "Pixel Arena Richmond",
        startsAt: "2026-09-19T18:30:00+10:00",
        format: "5v5 • BO3",
        registrationStatus: "open",
        checkedIn: false,
        checkedInAt: null,
        stations: [],
        squadId: null,
        matchId: null,
      },
    ],
    squads: [
      {
        id: "squad-five-stack",
        name: "Five Stack",
        players: [
          {
            id: "player-neonfox",
            handle: "NeonFox",
            role: "Duelist",
            isCaptain: true,
            isReady: true,
            isCurrentUser: false,
          },
          {
            id: "player-arclight",
            handle: "ArcLight",
            role: "Controller",
            isCaptain: false,
            isReady: true,
            isCurrentUser: false,
          },
          {
            id: "player-cyphercat",
            handle: "CypherCat",
            role: "Sentinel",
            isCaptain: false,
            isReady: true,
            isCurrentUser: false,
          },
          {
            id: "player-riftrunner",
            handle: "RiftRunner",
            role: "Initiator",
            isCaptain: false,
            isReady: true,
            isCurrentUser: false,
          },
          {
            id: "player-cong",
            handle: "Cong",
            role: null,
            isCaptain: false,
            isReady: false,
            isCurrentUser: true,
          },
        ],
      },
    ],
    matches: [
      {
        id: "match-round-2",
        eventId: "event-valorant-friday-lan",
        squadId: "squad-five-stack",
        round: "Round 2",
        opponent: "Team Nexus",
        scheduledAt: "2026-09-18T19:45:00+10:00",
        format: "BO1",
        status: "scheduled",
        stations: [],
        readyCount: 4,
        teamSize: 5,
      },
    ],
  };
}

/** Builds the QueueUp API with fresh in-memory seed state. */
export function buildServer(options: BuildServerOptions = {}): FastifyInstance {
  const app = Fastify({ logger: options.logger ?? true });
  const state = options.initialState ?? createSeedState();

  app.setErrorHandler((error, request, reply) => {
    // Technical detail stays server-side; the client only sees safe copy.
    request.log.error(error);
    reply.status(500).send(INTERNAL_ERROR_BODY);
  });

  app.setNotFoundHandler((_request, reply) => {
    reply.status(404).send(NOT_FOUND_BODY);
  });

  app.get("/health", async () => ({ ok: true }));

  app.get("/events", async () => state.events);

  app.get<{ Params: { eventId: string } }>("/events/:eventId", async (request, reply) => {
    const event = state.events.find((candidate) => candidate.id === request.params.eventId);
    if (!event) {
      return reply.status(404).send(NOT_FOUND_BODY);
    }
    return event;
  });

  app.get<{ Params: { squadId: string } }>("/squads/:squadId", async (request, reply) => {
    const squad = state.squads.find((candidate) => candidate.id === request.params.squadId);
    if (!squad) {
      return reply.status(404).send(NOT_FOUND_BODY);
    }
    return squad;
  });

  app.get<{ Params: { matchId: string } }>("/matches/:matchId", async (request, reply) => {
    const match = state.matches.find((candidate) => candidate.id === request.params.matchId);
    if (!match) {
      return reply.status(404).send(NOT_FOUND_BODY);
    }
    return match;
  });

  app.post<{ Params: { eventId: string } }>(
    "/events/:eventId/check-in",
    async (request, reply) => {
      const event = state.events.find((candidate) => candidate.id === request.params.eventId);
      const match = event
        ? state.matches.find((candidate) => candidate.eventId === event.id)
        : undefined;
      // Unknown event, or an event with no related match, fails closed.
      if (!event || !match) {
        return reply.status(404).send(NOT_FOUND_BODY);
      }

      // Idempotent: repeated calls keep the original stations and timestamp.
      if (!event.checkedIn) {
        event.checkedIn = true;
        event.checkedInAt = new Date().toISOString();
        event.stations = [...STATION_ASSIGNMENT];
        match.stations = [...STATION_ASSIGNMENT];
      }

      return { event, match };
    },
  );

  app.post<{ Params: { matchId: string } }>("/matches/:matchId/ready", async (request, reply) => {
    const match = state.matches.find((candidate) => candidate.id === request.params.matchId);
    if (!match) {
      return reply.status(404).send(NOT_FOUND_BODY);
    }

    const squad = state.squads.find((candidate) => candidate.id === match.squadId);
    const event = state.events.find((candidate) => candidate.id === match.eventId);
    const currentPlayer = squad?.players.find((player) => player.isCurrentUser);
    if (!squad || !event || !currentPlayer) {
      throw new Error(
        `Seed integrity violated: match ${match.id} has no squad, event, or current player.`,
      );
    }

    // Ready decision order: already ready, then check-in, then terminal status.
    if (currentPlayer.isReady) {
      return { match, squad };
    }

    if (!event.checkedIn) {
      return reply.status(409).send(CHECK_IN_REQUIRED_BODY);
    }

    if (match.status === "in_progress" || match.status === "complete") {
      return reply.status(409).send(MATCH_LOCKED_BODY);
    }

    currentPlayer.isReady = true;
    match.readyCount = squad.players.filter((player) => player.isReady).length;
    match.status = match.readyCount === match.teamSize ? "ready" : "scheduled";

    return { match, squad };
  });

  return app;
}
