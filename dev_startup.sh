#!/bin/bash
# Rails Development Startup Script with Hot-Reload Support
# This script handles:
# - Gemfile.lock conflict detection and resolution
# - Bundle install with hard rebuild fallback
# - Database creation and migrations
# - Dependency change detection for auto-reinstall
# - Rails server startup with hot-reload

set -e

echo "=========================================="
echo "Rails App Startup Script"
echo "=========================================="

# Ensure rbenv is initialized for the devcontainer user (avoid root-owned shims)
export RBENV_ROOT="${RBENV_ROOT:-/home/devcontainer/.rbenv}"
export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
if command -v rbenv >/dev/null 2>&1; then
    # Initialize rbenv and ensure the expected Ruby is installed for this user
    eval "$(rbenv init - bash)"
    if ! rbenv versions --bare | grep -q "^3.4.7$"; then
        echo "🔧 Installing Ruby 3.4.7 for devcontainer user..."
        rbenv install -s 3.4.7
    fi
    rbenv global 3.4.7
    # Ensure bundler is present for this Ruby
    gem install -N bundler -v 2.5.17 >/dev/null 2>&1 || true
fi

# Detect and remove Gemfile.lock merge conflicts (from git sync)
if [ -f "Gemfile.lock" ]; then
    if grep -q "^<<<<<<< " "Gemfile.lock" 2>/dev/null || \
       grep -q "^=======$" "Gemfile.lock" 2>/dev/null || \
       grep -q "^>>>>>>> " "Gemfile.lock" 2>/dev/null; then
        echo "⚠️  Detected merge conflict markers in Gemfile.lock"
        echo "   Removing Gemfile.lock to allow regeneration..."
        rm -f Gemfile.lock
    fi
fi

# Install gems with hard rebuild fallback
echo "📦 Installing gems..."
if ! bundle install --jobs=4 --retry=3; then
    echo "⚠️  Bundle install failed. Attempting hard rebuild..."
    echo "   Removing Gemfile.lock and vendor/bundle..."
    rm -f Gemfile.lock
    rm -rf vendor/bundle .bundle
    bundle install --jobs=4 --retry=3
fi

# Database setup (idempotent operations)
echo "🗄️  Setting up database..."
bundle exec rails db:create 2>/dev/null || echo "   Database already exists"
bundle exec rails db:migrate

# Hash-based dependency change detection
GEMFILE_HASH_FILE="/tmp/gemfile_hash.txt"
if [ -f "Gemfile.lock" ]; then
    CURRENT_HASH=$(md5sum Gemfile.lock | cut -d' ' -f1)

    if [ -f "$GEMFILE_HASH_FILE" ]; then
        PREVIOUS_HASH=$(cat "$GEMFILE_HASH_FILE")
        if [ "$CURRENT_HASH" != "$PREVIOUS_HASH" ]; then
            echo "📦 Gemfile.lock changed, running bundle install..."
            bundle install --jobs=4 --retry=3
        fi
    fi

    echo "$CURRENT_HASH" > "$GEMFILE_HASH_FILE"
fi

echo ""
echo "=========================================="
echo "Starting Rails Server"
echo "=========================================="
echo "  Environment: development"
echo "  Port: 8080"
echo "  Hot-reload: enabled"
echo ""

# Start Rails server
# -b 0.0.0.0: Bind to all interfaces (required for container access)
# -p 8080: Use port 8080 (App Platform standard)
exec bundle exec rails server -b 0.0.0.0 -p 8080
