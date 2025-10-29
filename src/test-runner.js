import { Database } from "bun:sqlite";
import { Elm } from "../elm-stuff/compiled/TestApp.js";

// Create in-memory SQLite database
const db = new Database(":memory:");

// Initialize the Elm app
const app = Elm.TestApp.init({
  flags: null,
});

// Set up port handlers
app.ports.executeMigration.subscribe((migrationSql) => {
  console.log("Executing migration:", migrationSql);
  try {
    db.exec(migrationSql);
    app.ports.queryResult.send({
      success: true,
      type: "migration",
      sql: migrationSql,
    });
  } catch (error) {
    console.error("Migration error:", error);
    app.ports.queryResult.send({
      success: false,
      type: "migration",
      error: String(error),
      sql: migrationSql,
    });
  }
});

app.ports.executeQuery.subscribe(({ query, params }) => {
  console.log("Executing query:", query, "with params:", params);
  try {
    const stmt = db.prepare(query);
    let result;

    if (query.trim().toLowerCase().startsWith("select")) {
      result = stmt.all(...params);
    } else {
      result = stmt.run(...params);
    }

    console.log("Query result:", result);
    app.ports.queryResult.send({
      success: true,
      type: "query",
      sql: query,
      result: result,
    });
  } catch (error) {
    console.error("Query error:", error);
    app.ports.queryResult.send({
      success: false,
      type: "query",
      error: String(error),
      sql: query,
    });
  }
});

// Listen for test completion
app.ports.queryResult.subscribe((result) => {
  if (result.type === "testComplete") {
    console.log("Tests completed!");

    // Verify the database state
    const users = db.prepare("SELECT * FROM users").all();
    const todos = db.prepare("SELECT * FROM todos").all();

    console.log("Users:", users);
    console.log("Todos:", todos);

    db.close();
    process.exit(0);
  }
});

// Set timeout to prevent hanging
setTimeout(() => {
  console.error("Test timed out!");
  db.close();
  process.exit(1);
}, 5000);
