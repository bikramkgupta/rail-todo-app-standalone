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

# Install rbenv/ruby-build at runtime if missing (handles images built without Ruby)
if ! command -v rbenv >/dev/null 2>&1; then
    echo "🔧 Installing rbenv for devcontainer user..."
    sudo apt-get update -y >/dev/null 2>&1
    sudo apt-get install -y --no-install-recommends \
        libreadline-dev libyaml-dev libz-dev libffi-dev libssl-dev build-essential git >/dev/null 2>&1
    git clone https://github.com/rbenv/rbenv.git "$RBENV_ROOT"
    git clone https://github.com/rbenv/ruby-build.git "$RBENV_ROOT/plugins/ruby-build"
    cd "$RBENV_ROOT" && src/configure && make -C src
    export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
fi

if command -v rbenv >/dev/null 2>&1; then
    # Initialize rbenv
    eval "$(rbenv init - bash)" 2>/dev/null || true
    
    # Detect required Ruby version from .ruby-version file (if present)
    REQUIRED_RUBY="3.4.7"
    if [ -f ".ruby-version" ]; then
        REQUIRED_RUBY=$(cat .ruby-version | tr -d '[:space:]' | sed 's/^ruby-//')
        echo "📋 Detected Ruby version requirement: $REQUIRED_RUBY"
    fi
    
    # Check if required Ruby version exists and is usable
    RUBY_AVAILABLE=false
    if [ -x "$RBENV_ROOT/versions/$REQUIRED_RUBY/bin/ruby" ]; then
        # Test if Ruby actually works (not broken paths)
        if "$RBENV_ROOT/versions/$REQUIRED_RUBY/bin/ruby" -v >/dev/null 2>&1; then
            RUBY_AVAILABLE=true
            echo "✓ Ruby $REQUIRED_RUBY is available and working"
        else
            echo "⚠️  Ruby $REQUIRED_RUBY exists but has broken paths, will reinstall"
        fi
    fi
    
    # If required Ruby is not available, check for any working Ruby version
    if [ "$RUBY_AVAILABLE" = "false" ]; then
        echo "🔍 Checking for available Ruby versions..."
        if [ -d "$RBENV_ROOT/versions" ]; then
            for ruby_dir in "$RBENV_ROOT/versions"/*; do
                if [ -d "$ruby_dir" ] && [ -x "$ruby_dir/bin/ruby" ]; then
                    RUBY_VER=$(basename "$ruby_dir")
                    if "$ruby_dir/bin/ruby" -v >/dev/null 2>&1; then
                        echo "✓ Found working Ruby version: $RUBY_VER"
                        REQUIRED_RUBY="$RUBY_VER"
                        RUBY_AVAILABLE=true
                        break
                    fi
                fi
            done
        fi
    fi
    
    # Install Ruby only if not available
    if [ "$RUBY_AVAILABLE" = "false" ]; then
        echo "🔧 Installing Ruby $REQUIRED_RUBY for devcontainer user..."
        echo "   (This may take 2-3 minutes...)"
        rbenv install -s "$REQUIRED_RUBY" || {
            echo "⚠️  Failed to install Ruby $REQUIRED_RUBY"
            echo "   Attempting to use system Ruby or available version..."
            # Try to use any available version
            AVAILABLE_VERSION=$(rbenv versions --bare 2>/dev/null | head -1)
            if [ -n "$AVAILABLE_VERSION" ]; then
                REQUIRED_RUBY="$AVAILABLE_VERSION"
                echo "   Using available Ruby version: $REQUIRED_RUBY"
            else
                echo "❌ No Ruby version available. Please check installation."
                exit 1
            fi
        }
    fi
    
    # Set Ruby version
    rbenv global "$REQUIRED_RUBY"
    rbenv local "$REQUIRED_RUBY" 2>/dev/null || true
    
    # Verify Ruby works
    if ! ruby -v >/dev/null 2>&1; then
        echo "❌ Ruby is not working. Please check installation."
        exit 1
    fi
    
    echo "✓ Using Ruby $(ruby -v | awk '{print $2}')"
    
    # Ensure bundler is present for this Ruby
    if ! bundle --version >/dev/null 2>&1; then
        echo "📦 Installing bundler..."
        gem install -N bundler -v 2.5.17 --force >/dev/null 2>&1 || true
    fi
else
    echo "❌ rbenv not found. Cannot proceed with Ruby setup."
    exit 1
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
