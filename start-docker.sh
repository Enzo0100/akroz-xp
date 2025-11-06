#!/bin/bash

docker compose up -d
sleep 60
docker compose exec rails bundle exec rails db:migrate
sleep 60

docker compose exec rails bundle exec rails db:seed

docker compose exec rails bundle exec rails db:chatwoot_prepare
