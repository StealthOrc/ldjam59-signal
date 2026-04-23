import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const frontendRoot = "C:/Users/Patrick/.codex/worktrees/b955/ldjam59-signal";
const backendRoot = "C:/Users/Patrick/.codex/worktrees/3e32/ldjam59-signal-backend";
const outputDirectory = path.join(frontendRoot, "outputs", "worktree-audit-20260423");
const outputFile = path.join(outputDirectory, "signal-worktree-communication-audit.xlsx");

const headerFill = "#16324F";
const headerText = "#FFFFFF";
const sectionFill = "#DCEAF7";
const activeFill = "#DCFCE7";
const resolvedFill = "#DBEAFE";
const unusedFill = "#FEF3C7";
const openFill = "#FEE2E2";
const textColor = "#0F172A";

const rows = [
  {
    area: "Transport",
    feature: "Single frontend request layer",
    frontend: `${frontendRoot}/src/game/network/leaderboard_fetch_thread.lua now delegates to leaderboard_client.lua for active request building.`,
    backend: `${backendRoot}/src/worker.ts remains the only backend entrypoint through wrangler.toml.`,
    status: "Resolved",
    used: "Yes",
    note: "The duplicate live request building drift between the thread worker and the direct client was removed.",
  },
  {
    area: "Leaderboard",
    feature: "GET /api/leaderboard and GET /api/maps/{map_uuid}/leaderboard",
    frontend: `${frontendRoot}/src/game/app/game_remote_services.lua begins the fetch and ${frontendRoot}/src/game/network/leaderboard_client.lua builds the request.`,
    backend: `${backendRoot}/src/worker.ts handleGlobalLeaderboard and handleMapLeaderboard serve the routes.`,
    status: "Active",
    used: "Yes",
    note: "This remains a normal active online flow.",
  },
  {
    area: "Replay preview",
    feature: "GET /api/maps/{map_uuid}/replays with optional player_uuid",
    frontend: `${frontendRoot}/src/game/app/game_remote_services.lua sends mapUuid, mapHash, and player_uuid. ${frontendRoot}/src/game/network/leaderboard_fetch_thread.lua forwards the replay metadata payload directly.`,
    backend: `${backendRoot}/src/worker.ts handleMapReplays now returns player_entry and target_rank when player_uuid is present.`,
    status: "Resolved",
    used: "Yes",
    note: "The previous preview gap is fixed in these worktrees.",
  },
  {
    area: "Replay submit",
    feature: "POST /api/maps/{map_uuid}/replays",
    frontend: `${frontendRoot}/src/game/app/game_profile_and_results.lua submitResultsScore uses replay upload as the main online write path.`,
    backend: `${backendRoot}/src/worker.ts handleSubmitReplay stores replay data and updates best_scores in the same request.`,
    status: "Active",
    used: "Yes",
    note: "This is the canonical online score write path for the game when a replay exists.",
  },
  {
    area: "Score only submit",
    feature: "POST /api/maps/{map_uuid}/score",
    frontend: `${frontendRoot}/src/game/network/leaderboard_client.lua still exposes submitScore, but the runtime does not call it.`,
    backend: `${backendRoot}/src/worker.ts handleSubmitScore still exists as a lightweight fallback route.`,
    status: "Unused",
    used: "No",
    note: "This route is still present but not used by the current game flow.",
  },
  {
    area: "Favorites",
    feature: "POST or DELETE /api/maps/{map_uuid}/favorites",
    frontend: `${frontendRoot}/src/game/network/marketplace_favorite_logic.lua now respects accepted and already_removed for unlike handling.`,
    backend: `${backendRoot}/src/worker.ts returns accepted and already_removed for the delete path.`,
    status: "Resolved",
    used: "Yes",
    note: "The live unlike response bug is fixed in these worktrees.",
  },
  {
    area: "Marketplace",
    feature: "GET /api/maps/favorites and GET /api/maps/search",
    frontend: `${frontendRoot}/src/game/app/game_remote_services.lua begins marketplace requests and leaderboard_client.lua builds them.`,
    backend: `${backendRoot}/src/worker.ts handleFavoriteMaps and handleMapSearch serve them.`,
    status: "Active",
    used: "Yes",
    note: "This remains an active online flow.",
  },
  {
    area: "Replay download",
    feature: "GET /api/maps/{map_uuid}/replays/{replay_uuid}",
    frontend: `${frontendRoot}/src/game/app/game_remote_services.lua beginReplayDownloadRequest uses the shared client path through leaderboard_fetch_thread.lua.`,
    backend: `${backendRoot}/src/worker.ts handleMapReplay returns replay metadata and replay payload.`,
    status: "Active",
    used: "Yes",
    note: "This remains an active online flow.",
  },
  {
    area: "Map upload",
    feature: "POST /api/maps",
    frontend: `${frontendRoot}/src/game/app/game_profile_and_results.lua uploadMapDescriptor and leaderboard_client.lua build the upload request.`,
    backend: `${backendRoot}/src/worker.ts handleCreateMap stores and updates shared maps.`,
    status: "Active",
    used: "Yes",
    note: "This remains an active online flow, gated by local config in the game UI.",
  },
  {
    area: "Around routes",
    feature: "GET /api/leaderboard/around and GET /api/maps/{map_uuid}/leaderboard/around",
    frontend: `No runtime caller is present in ${frontendRoot}.`,
    backend: `${backendRoot}/src/worker.ts still implements the routes.`,
    status: "Unused",
    used: "No",
    note: "These routes remain available but unused by the current game.",
  },
  {
    area: "Map lookup routes",
    feature: "GET /api/maps/id/{map_uuid} and GET /api/maps/code/{internal_identifier}",
    frontend: `No runtime caller is present in ${frontendRoot}.`,
    backend: `${backendRoot}/src/worker.ts still implements the routes.`,
    status: "Unused",
    used: "No",
    note: "These routes remain available but unused by the current game.",
  },
  {
    area: "Backend stale copy",
    feature: "src/worker.js",
    frontend: `No frontend caller ever used this file.`,
    backend: `${backendRoot}/src/worker.js is gone, and ${backendRoot}/src/worker.ts is the only worker implementation left.`,
    status: "Resolved",
    used: "No",
    note: "The stale duplicate backend file was removed in the current backend worktree.",
  },
];

const summaryRows = [
  ["Audit date", "2026-04-23"],
  ["Frontend worktree", frontendRoot],
  ["Backend worktree", backendRoot],
  ["State", "Current implementation in the supplied worktrees"],
  ["Main write path", "Replay submit is the canonical game write path and still carries score metadata"],
  ["Resolved issues in these worktrees", "Unlike response handling, replay preview player entry support, duplicate live request drift, stale backend worker copy"],
  ["Still unused", "Score only submit route, around routes, map lookup routes"],
];

function statusColor(status) {
  if (status === "Active") {
    return activeFill;
  }

  if (status === "Resolved") {
    return resolvedFill;
  }

  if (status === "Unused") {
    return unusedFill;
  }

  return openFill;
}

function styleHeader(range) {
  range.format = {
    fill: headerFill,
    font: {
      bold: true,
      color: headerText,
      name: "Aptos",
      size: 11,
    },
    horizontalAlignment: "center",
    verticalAlignment: "center",
    wrapText: true,
  };
}

function styleBody(range) {
  range.format = {
    font: {
      color: textColor,
      name: "Aptos",
      size: 10,
    },
    verticalAlignment: "top",
    wrapText: true,
  };
}

function styleSection(range) {
  range.format = {
    fill: sectionFill,
    font: {
      bold: true,
      color: textColor,
      name: "Aptos",
      size: 11,
    },
    verticalAlignment: "center",
  };
}

async function main() {
  const workbook = Workbook.create();
  const summarySheet = workbook.worksheets.add("Summary");
  const matrixSheet = workbook.worksheets.add("Current State");

  summarySheet.showGridLines = false;
  matrixSheet.showGridLines = false;

  summarySheet.getRange("A1:F1").merge();
  summarySheet.getRange("A1").values = [["Signal Worktree Communication Audit"]];
  summarySheet.getRange("A1").format = {
    fill: headerFill,
    font: {
      bold: true,
      color: headerText,
      name: "Aptos Display",
      size: 16,
    },
    horizontalAlignment: "left",
    verticalAlignment: "center",
  };

  summarySheet.getRange("A3:B9").values = summaryRows;
  styleSection(summarySheet.getRange("A3:A9"));
  styleBody(summarySheet.getRange("B3:B9"));

  summarySheet.getRange("D3:F3").merge();
  summarySheet.getRange("D3").values = [["Status legend"]];
  styleSection(summarySheet.getRange("D3:F3"));

  summarySheet.getRange("D4:F7").values = [
    ["Status", "Meaning", "Color"],
    ["Active", "Used by the current game runtime", "Active"],
    ["Resolved", "Previously wrong or duplicated, now fixed in the worktrees", "Resolved"],
    ["Unused", "Still implemented but not called by the current game runtime", "Unused"],
  ];
  styleHeader(summarySheet.getRange("D4:F4"));
  styleBody(summarySheet.getRange("D5:F7"));
  summarySheet.getRange("F5").format = { fill: statusColor("Active") };
  summarySheet.getRange("F6").format = { fill: statusColor("Resolved") };
  summarySheet.getRange("F7").format = { fill: statusColor("Unused") };

  const headers = [[
    "Area",
    "Feature",
    "Frontend implementation",
    "Backend implementation",
    "Used in runtime",
    "Status",
    "Current note",
  ]];
  matrixSheet.getRange("A1:G1").values = headers;
  styleHeader(matrixSheet.getRange("A1:G1"));

  const values = rows.map((row) => [
    row.area,
    row.feature,
    row.frontend,
    row.backend,
    row.used,
    row.status,
    row.note,
  ]);
  const endRow = values.length + 1;
  matrixSheet.getRange(`A2:G${endRow}`).values = values;
  styleBody(matrixSheet.getRange(`A2:G${endRow}`));

  for (let index = 0; index < rows.length; index += 1) {
    const rowNumber = index + 2;
    matrixSheet.getRange(`F${rowNumber}`).format = {
      fill: statusColor(rows[index].status),
      font: {
        bold: true,
        color: textColor,
        name: "Aptos",
        size: 10,
      },
      horizontalAlignment: "center",
    };
  }

  summarySheet.getRange("A:A").format.columnWidthPx = 170;
  summarySheet.getRange("B:B").format.columnWidthPx = 520;
  summarySheet.getRange("D:D").format.columnWidthPx = 100;
  summarySheet.getRange("E:E").format.columnWidthPx = 260;
  summarySheet.getRange("F:F").format.columnWidthPx = 100;

  matrixSheet.getRange("A:A").format.columnWidthPx = 120;
  matrixSheet.getRange("B:B").format.columnWidthPx = 220;
  matrixSheet.getRange("C:C").format.columnWidthPx = 360;
  matrixSheet.getRange("D:D").format.columnWidthPx = 360;
  matrixSheet.getRange("E:E").format.columnWidthPx = 100;
  matrixSheet.getRange("F:F").format.columnWidthPx = 100;
  matrixSheet.getRange("G:G").format.columnWidthPx = 320;

  matrixSheet.freezePanes.freezeRows(1);
  matrixSheet.freezePanes.freezeColumns(2);

  const summaryInspect = await workbook.inspect({
    kind: "table",
    range: "Summary!A1:F9",
    include: "values",
    tableMaxRows: 9,
    tableMaxCols: 6,
  });
  console.log(summaryInspect.ndjson);

  const matrixInspect = await workbook.inspect({
    kind: "table",
    range: `Current State!A1:G${endRow}`,
    include: "values",
    tableMaxRows: endRow,
    tableMaxCols: 7,
  });
  console.log(matrixInspect.ndjson);

  await workbook.render({
    sheetName: "Summary",
    range: "A1:F9",
    scale: 1,
    format: "png",
  });
  await workbook.render({
    sheetName: "Current State",
    range: `A1:G${endRow}`,
    scale: 1,
    format: "png",
  });

  await fs.mkdir(outputDirectory, { recursive: true });
  const output = await SpreadsheetFile.exportXlsx(workbook);
  await output.save(outputFile);
  console.log(`Workbook saved to ${outputFile}`);
}

await main();
