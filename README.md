# Rail Todo App

Standalone Ruby on Rails to-do list application with Bootstrap UI, ready for hot-reload development on DigitalOcean App Platform using the `hot-reload-template` Dockerfile.

## Features
- Rails 8.1.x on Ruby 3.4.7
- CRUD tasks (title, description, completed)
- Bootstrap 5 responsive layout
- SQLite for development, PostgreSQL-ready for production
- `dev_startup.sh` handles bundle install, migrations, and hot-reload server startup

## Local Development
```bash
bundle install
bin/rails db:prepare   # creates + migrates (uses SQLite)
bin/rails s -b 0.0.0.0 -p 3000
```

## Hot-Reload on DigitalOcean App Platform
This repo is deployed using the `hot-reload-template` Dockerfile (from the template repo) plus the `dev_startup.sh` in this repo. The App Platform spec is in `app.yaml`.

Key environment variables (set in App Platform UI or spec):
- `GITHUB_REPO_URL`: `https://github.com/bikramkgupta/rail-todo-app-standalone`
- `GITHUB_BRANCH`: `main`
- `DEV_START_COMMAND`: `bash dev_startup.sh`
- `ENABLE_DEV_HEALTH`: `true` initially; switch to `false` after your app health endpoint is ready
- `RAILS_ENV`: `development` for hot-reload
- `GITHUB_TOKEN`: required for private repos

Key build arguments (App Platform build args):
- `INSTALL_RUBY=true`, `INSTALL_NODE=false`, `INSTALL_PYTHON=false`, `INSTALL_GOLANG=false`, `INSTALL_RUST=false`
- `RUBY_VERSIONS="3.4 3.3"`, `DEFAULT_RUBY="3.4"`
- `INSTALL_POSTGRES=true` if you want psql client available

### Deploy (CLI)
```bash
doctl apps create --spec app.yaml
```

### Deploy (UI)
1) Create App → GitHub → use this repo  
2) In App Spec, set `dockerfile_path: hot-reload-template/Dockerfile` and `github.repo` to the hot-reload-template repo (see `app.yaml` for example)  
3) Add env vars/build args above  
4) Deploy, then tail logs to confirm Ruby install and Rails boot

## Tests
```bash
bundle exec rails test
```

## Useful Links
- Hot-reload template repo: https://github.com/bikram20/do-app-platform-ai-dev-workflow
- DigitalOcean App Platform docs: https://docs.digitalocean.com/products/app-platform/
