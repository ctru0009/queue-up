import assert from "node:assert/strict";
import { test } from "node:test";

import type { FastifyInstance } from "fastify";

import {
  buildServer,
  type Event,
  type Match,
  type MatchStatus,
  type SeedState,
  type Squad,
} from "../src/app.js";

/** Frozen wire enum for `Match.status`. */
const WIRE_MATCH_STATUSES: readonly MatchStatus[] = [
  "scheduled",
  "ready",
  "in_progress",
  "complete",
];

/** Station assignment committed to the event and its match by check-in. */
const REQUIRED_STATIONS = ["B11", "B12", "B13", "B14", "B15"];

const NOT_FOUND_BODY = {
  error: "NOT_FOUND",
  message: "The requested resource was not found.",
};

const CHECK_IN_REQUIRED_BODY = {
  error: "CHECK_IN_REQUIRED",
  message: "Check in before marking ready.",
};

const featuredEvent: Event = {
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
};

const riftCupEvent: Event = {
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
};

const cs2Event: Event = {
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
};

const fiveStack: Squad = {
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
};

const roundTwoMatch: Match = {
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
};

/** Runs `run` against one server instance and always closes it afterwards. */
async function withServer(run: (app: FastifyInstance) => Promise<void>): Promise<void> {
  const app = buildServer({ logger: false });
  try {
    await run(app);
  } finally {
    await app.close();
  }
}

test("GET /health reports ok", async () => {
  const app = buildServer({ logger: false });
  try {
    const response = await app.inject({ method: "GET", url: "/health" });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { ok: true });
  } finally {
    await app.close();
  }
});

test("GET /events returns exactly three summaries in the frozen order", async () => {
  await withServer(async (app) => {
    const response = await app.inject({ method: "GET", url: "/events" });

    assert.equal(response.statusCode, 200);
    const summaries = response.json<Event[]>();
    assert.deepEqual(summaries, [featuredEvent, riftCupEvent, cs2Event]);

    assert.equal(summaries.length, 3);
    assert.equal(summaries[0]?.id, "event-valorant-friday-lan");
    assert.equal(summaries[0]?.squadId, "squad-five-stack");
    assert.equal(summaries[0]?.matchId, "match-round-2");

    for (const secondary of summaries.slice(1)) {
      assert.equal(secondary.squadId, null);
      assert.equal(secondary.matchId, null);
      assert.equal(secondary.checkedIn, false);
      assert.equal(secondary.checkedInAt, null);
      assert.deepEqual(secondary.stations, []);
    }
  });
});

test("GET /events/:eventId returns featured detail and reduced secondary detail", async () => {
  await withServer(async (app) => {
    const featured = await app.inject({
      method: "GET",
      url: "/events/event-valorant-friday-lan",
    });
    assert.equal(featured.statusCode, 200);
    assert.deepEqual(featured.json(), featuredEvent);

    const secondary = await app.inject({
      method: "GET",
      url: "/events/event-cs2-saturday-clash",
    });
    assert.equal(secondary.statusCode, 200);
    assert.deepEqual(secondary.json(), cs2Event);
  });
});

test("GET /events/:eventId returns the safe 404 body for an unknown event", async () => {
  await withServer(async (app) => {
    const response = await app.inject({ method: "GET", url: "/events/event-unknown" });

    assert.equal(response.statusCode, 404);
    assert.equal(response.body, JSON.stringify(NOT_FOUND_BODY));
  });
});

test("GET /squads/:squadId returns Five Stack with one captain, one current user, and four ready players", async () => {
  await withServer(async (app) => {
    const response = await app.inject({ method: "GET", url: "/squads/squad-five-stack" });

    assert.equal(response.statusCode, 200);
    const squad = response.json<Squad>();
    assert.deepEqual(squad, fiveStack);

    assert.equal(squad.name, "Five Stack");
    assert.equal(squad.players.length, 5);
    assert.equal(squad.players.filter((player) => player.isCurrentUser).length, 1);
    assert.equal(squad.players.filter((player) => player.isCaptain).length, 1);
    assert.equal(squad.players.filter((player) => player.isReady).length, 4);

    const cong = squad.players.find((player) => player.id === "player-cong");
    assert.equal(cong?.handle, "Cong");
    assert.equal(cong?.role, null);
    assert.equal(cong?.isCurrentUser, true);
  });
});

test("GET /squads/:squadId returns the safe 404 body for an unknown squad", async () => {
  await withServer(async (app) => {
    const response = await app.inject({ method: "GET", url: "/squads/squad-unknown" });

    assert.equal(response.statusCode, 404);
    assert.equal(response.body, JSON.stringify(NOT_FOUND_BODY));
  });
});

test("GET /matches/:matchId returns the frozen match in scheduled state", async () => {
  await withServer(async (app) => {
    const response = await app.inject({ method: "GET", url: "/matches/match-round-2" });

    assert.equal(response.statusCode, 200);
    const match = response.json<Match>();
    assert.deepEqual(match, roundTwoMatch);

    assert.equal(match.round, "Round 2");
    assert.equal(match.opponent, "Team Nexus");
    assert.equal(match.scheduledAt, "2026-09-18T19:45:00+10:00");
    assert.equal(match.format, "BO1");
    assert.equal(match.status, "scheduled");
    assert.deepEqual(match.stations, []);
    assert.equal(match.readyCount, 4);
    assert.equal(match.teamSize, 5);
    assert.equal(WIRE_MATCH_STATUSES.includes(match.status), true);
  });
});

test("unknown resource ids and unknown routes use the safe 404 body", async () => {
  await withServer(async (app) => {
    const unknownMatch = await app.inject({ method: "GET", url: "/matches/match-unknown" });
    assert.equal(unknownMatch.statusCode, 404);
    assert.equal(unknownMatch.body, JSON.stringify(NOT_FOUND_BODY));

    const unknownRoute = await app.inject({ method: "GET", url: "/not-a-route" });
    assert.equal(unknownRoute.statusCode, 404);
    assert.equal(unknownRoute.body, JSON.stringify(NOT_FOUND_BODY));
  });
});

test("ready before check-in is rejected, check-in commits stations, and ready completes the workflow", async () => {
  await withServer(async (app) => {
    const blocked = await app.inject({
      method: "POST",
      url: "/matches/match-round-2/ready",
    });
    assert.equal(blocked.statusCode, 409);
    assert.equal(blocked.body, JSON.stringify(CHECK_IN_REQUIRED_BODY));

    const blockedList = await app.inject({ method: "GET", url: "/events" });
    assert.deepEqual(blockedList.json(), [featuredEvent, riftCupEvent, cs2Event]);

    const checkedIn = await app.inject({
      method: "POST",
      url: "/events/event-valorant-friday-lan/check-in",
    });
    assert.equal(checkedIn.statusCode, 200);
    const checkInBody = checkedIn.json<{ event: Event; match: Match }>();
    assert.equal(checkInBody.event.checkedIn, true);
    assert.equal(typeof checkInBody.event.checkedInAt, "string");
    assert.notEqual(checkInBody.event.checkedInAt, null);
    assert.equal(Number.isNaN(Date.parse(checkInBody.event.checkedInAt ?? "")), false);
    assert.deepEqual(checkInBody.event.stations, REQUIRED_STATIONS);
    assert.deepEqual(checkInBody.match.stations, REQUIRED_STATIONS);
    assert.equal(checkInBody.match.readyCount, 4);
    assert.equal(checkInBody.match.status, "scheduled");

    const ready = await app.inject({
      method: "POST",
      url: "/matches/match-round-2/ready",
    });
    assert.equal(ready.statusCode, 200);
    const readyBody = ready.json<{ match: Match; squad: Squad }>();
    assert.equal(readyBody.match.readyCount, 5);
    assert.equal(readyBody.match.status, "ready");
    assert.equal(
      readyBody.squad.players.find((player) => player.id === "player-cong")?.isReady,
      true,
    );

    const repeated = await app.inject({
      method: "POST",
      url: "/matches/match-round-2/ready",
    });
    assert.equal(repeated.statusCode, 200);
    assert.deepEqual(repeated.json(), readyBody);

    const [eventGet, matchGet, squadGet, listGet] = await Promise.all([
      app.inject({ method: "GET", url: "/events/event-valorant-friday-lan" }),
      app.inject({ method: "GET", url: "/matches/match-round-2" }),
      app.inject({ method: "GET", url: "/squads/squad-five-stack" }),
      app.inject({ method: "GET", url: "/events" }),
    ]);

    assert.deepEqual(eventGet.json(), checkInBody.event);
    assert.deepEqual(matchGet.json(), readyBody.match);
    assert.deepEqual(squadGet.json(), readyBody.squad);
    assert.deepEqual(listGet.json<Event[]>()[0], checkInBody.event);
  });
});

test("check-in is idempotent and preserves the original checkedInAt", async () => {
  await withServer(async (app) => {
    const first = await app.inject({
      method: "POST",
      url: "/events/event-valorant-friday-lan/check-in",
    });
    assert.equal(first.statusCode, 200);
    const firstBody = first.json<{ event: Event; match: Match }>();
    assert.deepEqual(firstBody.event.stations, REQUIRED_STATIONS);
    assert.deepEqual(firstBody.match.stations, REQUIRED_STATIONS);

    const second = await app.inject({
      method: "POST",
      url: "/events/event-valorant-friday-lan/check-in",
    });
    assert.equal(second.statusCode, 200);
    const secondBody = second.json<{ event: Event; match: Match }>();

    assert.equal(secondBody.event.checkedInAt, firstBody.event.checkedInAt);
    assert.deepEqual(secondBody.event.stations, REQUIRED_STATIONS);
    assert.deepEqual(secondBody.match.stations, REQUIRED_STATIONS);
    assert.deepEqual(secondBody, firstBody);
  });
});

test("check-in for an unknown event fails closed with 404 and mutates nothing", async () => {
  await withServer(async (app) => {
    const before = (await app.inject({ method: "GET", url: "/events" })).json<Event[]>();

    const response = await app.inject({
      method: "POST",
      url: "/events/event-unknown/check-in",
    });
    assert.equal(response.statusCode, 404);
    assert.equal(response.body, JSON.stringify(NOT_FOUND_BODY));

    const after = (await app.inject({ method: "GET", url: "/events" })).json<Event[]>();
    assert.deepEqual(after, before);
  });
});

test("check-in for an event with no related match fails closed with 404 and mutates nothing", async () => {
  await withServer(async (app) => {
    const before = (await app.inject({ method: "GET", url: "/events" })).json<Event[]>();

    const response = await app.inject({
      method: "POST",
      url: "/events/event-melbourne-rift-cup/check-in",
    });
    assert.equal(response.statusCode, 404);
    assert.equal(response.body, JSON.stringify(NOT_FOUND_BODY));

    const after = (await app.inject({ method: "GET", url: "/events" })).json<Event[]>();
    assert.deepEqual(after, before);

    const detail = await app.inject({
      method: "GET",
      url: "/events/event-melbourne-rift-cup",
    });
    assert.deepEqual(detail.json(), riftCupEvent);
  });
});

test("ready for an unknown match returns the safe 404 body", async () => {
  await withServer(async (app) => {
    const response = await app.inject({
      method: "POST",
      url: "/matches/match-unknown/ready",
    });

    assert.equal(response.statusCode, 404);
    assert.equal(response.body, JSON.stringify(NOT_FOUND_BODY));
  });
});

/**
 * Builds a checked-in, fully assigned state whose match sits in a status the
 * public workflow cannot produce: no endpoint advances a match past `ready`.
 * Ready-decision step 1 returns early when the current player is already ready,
 * so reaching the terminal-status guard requires a locked match in which the
 * current player has not readied.
 */
function lockedMatchState(status: MatchStatus): SeedState {
  return {
    events: [
      {
        ...featuredEvent,
        checkedIn: true,
        checkedInAt: "2026-09-18T19:05:00+10:00",
        stations: [...REQUIRED_STATIONS],
      },
    ],
    squads: [
      {
        ...fiveStack,
        players: fiveStack.players.map((player) => ({ ...player })),
      },
    ],
    matches: [{ ...roundTwoMatch, status, stations: [...REQUIRED_STATIONS], readyCount: 4 }],
  };
}

for (const status of ["in_progress", "complete"] as const) {
  test(`ready is refused while the match is ${status} and mutates nothing`, async () => {
    const app = buildServer({ logger: false, initialState: lockedMatchState(status) });
    try {
      const response = await app.inject({
        method: "POST",
        url: "/matches/match-round-2/ready",
      });

      assert.equal(response.statusCode, 409);
      assert.equal(
        response.body,
        JSON.stringify({
          error: "MATCH_LOCKED",
          message: "Readiness is closed for this match.",
        }),
      );

      // The rejected transition left every entity exactly as it was.
      const match = (
        await app.inject({ method: "GET", url: "/matches/match-round-2" })
      ).json<Match>();
      assert.equal(match.status, status);
      assert.equal(match.readyCount, 4);

      const squad = (
        await app.inject({ method: "GET", url: "/squads/squad-five-stack" })
      ).json<Squad>();
      const currentPlayer = squad.players.find((player) => player.isCurrentUser);
      assert.equal(currentPlayer?.isReady, false);
      assert.equal(squad.players.filter((player) => player.isReady).length, 4);
    } finally {
      await app.close();
    }
  });
}

test("two buildServer instances keep independent state", async () => {
  const mutated = buildServer({ logger: false });
  const pristine = buildServer({ logger: false });
  try {
    const checkIn = await mutated.inject({
      method: "POST",
      url: "/events/event-valorant-friday-lan/check-in",
    });
    assert.equal(checkIn.statusCode, 200);
    const ready = await mutated.inject({
      method: "POST",
      url: "/matches/match-round-2/ready",
    });
    assert.equal(ready.statusCode, 200);
    assert.equal(ready.json<{ match: Match }>().match.status, "ready");

    const events = await pristine.inject({ method: "GET", url: "/events" });
    assert.deepEqual(events.json(), [featuredEvent, riftCupEvent, cs2Event]);

    const match = await pristine.inject({ method: "GET", url: "/matches/match-round-2" });
    assert.deepEqual(match.json(), roundTwoMatch);

    const squad = await pristine.inject({
      method: "GET",
      url: "/squads/squad-five-stack",
    });
    assert.deepEqual(squad.json(), fiveStack);
  } finally {
    await mutated.close();
    await pristine.close();
  }
});

test("match status serialized by the API always comes from the frozen wire enum", async () => {
  await withServer(async (app) => {
    // The frozen seed cannot reach `in_progress` or `complete` through the
    // public API — no endpoint advances a match past `ready` — so this test
    // covers what the default seed can observe end to end: every serialized
    // status belongs to the frozen wire enum, and only the two reachable values
    // ever appear, even after the full workflow. The terminal-status guard
    // itself is covered separately by injecting a locked match.
    const initial = await app.inject({ method: "GET", url: "/matches/match-round-2" });
    const initialStatus = initial.json<Match>().status;
    assert.equal(initialStatus, "scheduled");
    assert.equal(WIRE_MATCH_STATUSES.includes(initialStatus), true);

    await app.inject({ method: "POST", url: "/events/event-valorant-friday-lan/check-in" });
    const afterCheckIn = await app.inject({ method: "GET", url: "/matches/match-round-2" });
    const afterCheckInStatus = afterCheckIn.json<Match>().status;
    assert.equal(afterCheckInStatus, "scheduled");
    assert.equal(WIRE_MATCH_STATUSES.includes(afterCheckInStatus), true);

    await app.inject({ method: "POST", url: "/matches/match-round-2/ready" });
    const afterReady = await app.inject({ method: "GET", url: "/matches/match-round-2" });
    const afterReadyStatus = afterReady.json<Match>().status;
    assert.equal(afterReadyStatus, "ready");
    assert.equal(WIRE_MATCH_STATUSES.includes(afterReadyStatus), true);

    assert.deepEqual(
      [...new Set([initialStatus, afterCheckInStatus, afterReadyStatus])],
      ["scheduled", "ready"],
    );
  });
});

test("unexpected route failures return the generic safe 500 body without internals", async () => {
  await withServer(async (app) => {
    // Test-owned route: the only way to exercise the error handler over HTTP,
    // since no shipped route throws for valid input.
    app.get("/__test__/unexpected-failure", async () => {
      throw new Error("leaked detail: /Users/secret/api/src/app.ts exploded");
    });

    const response = await app.inject({
      method: "GET",
      url: "/__test__/unexpected-failure",
    });

    assert.equal(response.statusCode, 500);
    assert.equal(
      response.body,
      JSON.stringify({ error: "INTERNAL_ERROR", message: "Something went wrong." }),
    );
    assert.equal(response.body.includes("leaked detail"), false);
    assert.equal(response.body.includes("/Users/secret"), false);
    assert.equal(response.body.includes("stack"), false);
  });
});
