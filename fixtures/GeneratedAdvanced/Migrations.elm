module GeneratedAdvanced.Migrations exposing (..)

init : String
init =
    """
    -- Create tables for the main entities

    -- Application table
    CREATE TABLE IF NOT EXISTS application (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
    );

    -- UserDefinedTable table
    CREATE TABLE IF NOT EXISTS user_defined_table (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        column_defs JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
    );

    -- Row table
    CREATE TABLE IF NOT EXISTS row (
        id SERIAL PRIMARY KEY,
        user_defined_table_id INTEGER NOT NULL,
        values JSONB NOT NULL,
        normalized VARCHAR(255) NOT NULL,
        vector_data VECTOR(1024) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        FOREIGN KEY (user_defined_table_id) REFERENCES user_defined_table(id) ON DELETE CASCADE
    );

    -- RankResult table
    CREATE TABLE IF NOT EXISTS rank_result (
        id SERIAL PRIMARY KEY,
        reference JSONB NOT NULL,
        subject JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
    );

    -- Join table for Application to UserDefinedTable (Multilink)
    CREATE TABLE IF NOT EXISTS application_user_defined_table (
        application_id INTEGER NOT NULL,
        user_defined_table_id INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
        PRIMARY KEY (application_id, user_defined_table_id),
        FOREIGN KEY (application_id) REFERENCES application(id) ON DELETE CASCADE,
        FOREIGN KEY (user_defined_table_id) REFERENCES user_defined_table(id) ON DELETE CASCADE
    );

    -- Create indexes for performance
    CREATE INDEX IF NOT EXISTS idx_row_user_defined_table_id ON row(user_defined_table_id);
    CREATE INDEX IF NOT EXISTS idx_application_user_defined_table_app_id ON application_user_defined_table(application_id);
    CREATE INDEX IF NOT EXISTS idx_application_user_defined_table_table_id ON application_user_defined_table(user_defined_table_id);

    -- Create vector index for similarity searches (requires pgvector extension)
    CREATE INDEX IF NOT EXISTS vector_idx ON row USING ivfflat (vector_data vector_cosine_ops);
    """