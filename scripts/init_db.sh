#!/usr/bin/env bash

set +x           # debug mode running. prints all commands before running them -x. +x to turn off
set -eo pipefail # exit on error -e, exit on error in pipe -o pipefail. this ensures that the script will exit if any command fails

function check_for_mandatory_commands {
  if ! [ -x "$(command -v psql)" ]; then
    echo >&2 "Error: psql is not installed."
    exit 1
  fi
  if ! [ -x "$(command -v sqlx)" ]; then
    echo >&2 "Error: sqlx is not installed."
    echo >&2 "Use:"
    echo >&2 "cargo install --version='~0.6' sqlx-cli --no-default-features --features rustls,postgres"
    echo >&2 "to install it."
    exit 1
  fi

}

function set_env_vars {
  # Check if a custom user has been set, otherwise default to 'postgres'
  DB_USER=${POSTGRES_USER:=postgres}
  DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
  DB_NAME="${POSTGRES_DB:=newsletter}"
  DB_PORT="${POSTGRES_PORT:=5432}"
  DB_HOST="${POSTGRES_HOST:=localhost}"
}

function dev_db_is_running {
  local container_name="zero2prod_dev_db"

  if docker ps --filter "name=$container_name" --quiet | grep -q .; then
    echo "Container '$container_name' is running."
    return 0
  else
    echo "Container '$container_name' is not running."
    return 1
  fi
}

function run_dev_db_if_not_running {
  if ! dev_db_is_running; then
    docker run \
      --name zero2prod_dev_db \
      -e POSTGRES_USER=${DB_USER} \
      -e POSTGRES_PASSWORD=${DB_PASSWORD} \
      -e POSTGRES_DB=${DB_NAME} \
      -p "${DB_PORT}":5432 \
      -d postgres \
      postgres -N 1000
  # ^ Increased maximum number of connections for testing purposes
  fi

}

function wait_for_postgres {
  # Keep pinging Postgres until it's ready to accept commands
  export PGPASSWORD="${DB_PASSWORD}"
  until psql -h "${DB_HOST}" -U "${DB_USER}" -p "${DB_PORT}" -d "postgres" -c '\q'; do
    >&2 echo "Postgres is still unavailable - sleeping"
    sleep 1
  done
  >&2 echo "Postgres is up and running on port ${DB_PORT}!"
}

function configure_dev_db {
  DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
  export DATABASE_URL
  sqlx database create
  sqlx migrate run

  >&2 echo "Postgres has been migrated, ready to go!"
}

function main {
  check_for_mandatory_commands
  set_env_vars
  run_dev_db_if_not_running
  wait_for_postgres
  configure_dev_db
}
