import { test, expect } from "bun:test";
import { Database } from "bun:sqlite";
import { generate } from "./generator";

async function getGeneratedMigrations(): Promise<string> {
  const result = await generate("src/ORM.elm");
  return result.migrations;
}

test("Generated migrations should create actual SQLite tables", async () => {
  const migrationsCode = await getGeneratedMigrations();
  
  // Extract SQL from the generated Elm code
  const userTableMatch = migrationsCode.match(/usersCreateTable\s*=\s*"""([^"]+)"""/);
  const todoTableMatch = migrationsCode.match(/todosCreateTable\s*=\s*"""([^"]+)"""/);
  
  expect(userTableMatch).toBeTruthy();
  expect(todoTableMatch).toBeTruthy();
  
  const userTableSql = userTableMatch![1].trim();
  const todoTableSql = todoTableMatch![1].trim();
  
  // Create in-memory SQLite database
  const db = new Database(":memory:");
  
  // Execute the generated migrations
  db.exec(userTableSql);
  db.exec(todoTableSql);
  
  // Verify tables were created
  const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table'").all();
  const tableNames = tables.map((row: any) => row.name);
  
  expect(tableNames).toContain("users");
  expect(tableNames).toContain("todos");
  
  // Verify table structure
  const userColumns = db.prepare("PRAGMA table_info(users)").all();
  const todoColumns = db.prepare("PRAGMA table_info(todos)").all();
  
  const userColumnNames = userColumns.map((col: any) => col.name);
  const todoColumnNames = todoColumns.map((col: any) => col.name);
  
  // Check for auto-added fields
  expect(userColumnNames).toContain("id");
  expect(userColumnNames).toContain("created_at");
  expect(userColumnNames).toContain("updated_at");
  expect(userColumnNames).toContain("name"); // User-defined field
  
  expect(todoColumnNames).toContain("id");
  expect(todoColumnNames).toContain("created_at"); 
  expect(todoColumnNames).toContain("updated_at");
  expect(todoColumnNames).toContain("description"); // User-defined field
  
  db.close();
});

test("SQLite integration - Insert and query data", async () => {
  const migrationsCode = await getGeneratedMigrations();
  
  const userTableMatch = migrationsCode.match(/usersCreateTable\s*=\s*"""([^"]+)"""/);
  const todoTableMatch = migrationsCode.match(/todosCreateTable\s*=\s*"""([^"]+)"""/);
  
  const userTableSql = userTableMatch![1].trim();
  const todoTableSql = todoTableMatch![1].trim();
  
  const db = new Database(":memory:");
  
  db.exec(userTableSql);
  db.exec(todoTableSql);
  
  // Insert test data
  const insertUser = db.prepare("INSERT INTO users (name) VALUES (?)");
  const insertTodo = db.prepare("INSERT INTO todos (description) VALUES (?)");
  
  const userId = insertUser.run("John Doe").lastInsertRowid;
  const todoId = insertTodo.run("Learn Elm ORM").lastInsertRowid;
  
  // Query data
  const users = db.prepare("SELECT * FROM users").all();
  const todos = db.prepare("SELECT * FROM todos").all();
  
  expect(users).toHaveLength(1);
  expect(todos).toHaveLength(1);
  
  expect(users[0].name).toBe("John Doe");
  expect(users[0].id).toBe(userId);
  expect(users[0].created_at).toBeTruthy();
  expect(users[0].updated_at).toBeTruthy();
  
  expect(todos[0].description).toBe("Learn Elm ORM");
  expect(todos[0].id).toBe(todoId);
  expect(todos[0].created_at).toBeTruthy();
  expect(todos[0].updated_at).toBeTruthy();
  
  db.close();
});

test("SQLite vector operations test", async () => {
  const migrationsCode = await getGeneratedMigrations();
  
  const userTableMatch = migrationsCode.match(/usersCreateTable\s*=\s*"""([^"]+)"""/);
  const userTableSql = userTableMatch![1].trim();
  
  const db = new Database(":memory:");
  db.exec(userTableSql);
  
  // Insert multiple users for vector-like operations
  const insertUser = db.prepare("INSERT INTO users (name) VALUES (?)");
  const users = ["Alice", "Bob", "Charlie", "Diana"];
  
  for (const name of users) {
    insertUser.run(name);
  }
  
  // Test batch operations (vector-like)
  const allUsers = db.prepare("SELECT * FROM users ORDER BY name").all();
  expect(allUsers).toHaveLength(4);
  
  const names = allUsers.map((user: any) => user.name);
  expect(names).toEqual(["Alice", "Bob", "Charlie", "Diana"]);
  
  // Test filtering (vector operations)
  const filteredUsers = db.prepare("SELECT * FROM users WHERE name LIKE 'A%'").all();
  expect(filteredUsers).toHaveLength(1);
  expect(filteredUsers[0].name).toBe("Alice");
  
  // Test bulk update (vector operations)
  const updateResult = db.prepare("UPDATE users SET updated_at = CURRENT_TIMESTAMP WHERE name LIKE '%a%'").run();
  expect(updateResult.changes).toBeGreaterThan(0);
  
  db.close();
});