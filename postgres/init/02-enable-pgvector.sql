-- Enable pgvector extension on the memory database for Mem0
\connect memory;
CREATE EXTENSION IF NOT EXISTS vector;

-- Also enable uuid-ossp for generating unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
