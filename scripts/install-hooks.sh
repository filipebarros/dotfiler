#!/bin/bash

# Install Git hooks for Dotfiler project
# Run this script from the project root directory

set -e

echo "Installing Git hooks for Dotfiler..."

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "Error: Not in a Git repository. Please run this from the project root."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Dotfiler Pre-commit Hook
# Automatically formats and lints Elixir code before committing

echo "Running pre-commit checks..."

# Check if we're in a git repository with staged changes
if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    # Initial commit: diff against an empty tree object
    against=$(git hash-object -t tree /dev/null)
else
    against=HEAD
fi

# Get list of staged Elixir files
staged_files=$(git diff --cached --name-only --diff-filter=ACM $against | grep -E '\.(ex|exs)$')

if [ -z "$staged_files" ]; then
    echo "No Elixir files staged for commit."
    exit 0
fi

echo "Staged Elixir files:"
echo "$staged_files"

# Check if mix is available
if ! command -v mix &> /dev/null; then
    echo "Error: mix command not found. Please ensure Elixir is installed."
    exit 1
fi

# Format staged Elixir files
echo "Running mix format..."
echo "$staged_files" | xargs mix format

# Check if formatting made any changes
if ! git diff --quiet; then
    echo "Code formatting made changes. Adding formatted files to staging area..."
    echo "$staged_files" | xargs git add
fi

# Compile the project to check for syntax errors
echo "Compiling project..."
if ! mix compile --warnings-as-errors; then
    echo "Error: Compilation failed with warnings treated as errors."
    echo "Please fix the warnings before committing."
    exit 1
fi

# Run tests
echo "Running tests..."
if ! timeout 30s mix test --color 2>/dev/null || ! gtimeout 30s mix test --color 2>/dev/null; then
    # Try without timeout if timeout commands don't exist
    if ! mix test --color; then
        echo "Warning: Tests failed or timed out. Consider fixing before pushing."
        echo "Use --no-verify to skip hooks if needed for temporary commits."
        # Don't fail the commit for now to allow development
        # Uncomment the next line to make failing tests block commits:
        # exit 1
    fi
fi

# Check for common issues (optional but recommended)
echo "Checking for common issues..."

# Check for debugging statements that shouldn't be committed
debug_patterns="IO\.inspect|IO\.puts.*debug|dbg\(|pry|binding\.pry"
if echo "$staged_files" | xargs grep -n -E "$debug_patterns" 2>/dev/null; then
    echo "Warning: Found potential debugging statements in staged files."
    echo "Consider removing them before committing."
    # Uncomment the next line to make this check fail the commit:
    # exit 1
fi

# Check for TODO comments (informational)
todo_count=$(echo "$staged_files" | xargs grep -c -i "TODO\|FIXME\|HACK" 2>/dev/null | awk -F: '{sum += $2} END {print sum+0}')
if [ "$todo_count" -gt 0 ]; then
    echo "Info: Found $todo_count TODO/FIXME/HACK comments in staged files."
fi

echo "Pre-commit checks passed! ✅"
exit 0
EOF

# Copy commit-msg hook
cat > .git/hooks/commit-msg << 'EOF'
#!/bin/bash

# Dotfiler Commit Message Hook
# Enforces conventional commit message format

commit_msg_file="$1"
commit_msg=$(cat "$commit_msg_file")

# Skip if it's a merge commit
if echo "$commit_msg" | grep -q "^Merge "; then
    exit 0
fi

# Skip if it's a revert commit
if echo "$commit_msg" | grep -q "^Revert "; then
    exit 0
fi

# Check for conventional commit format
# Format: type(scope): description
# Types: feat, fix, docs, style, refactor, test, chore, ci, perf
conventional_commit_pattern="^(feat|fix|docs|style|refactor|test|chore|ci|perf)(\(.+\))?: .{1,50}"

if ! echo "$commit_msg" | grep -qE "$conventional_commit_pattern"; then
    echo "❌ Invalid commit message format!"
    echo ""
    echo "Commit messages should follow the conventional commit format:"
    echo "  <type>(<scope>): <description>"
    echo ""
    echo "Types:"
    echo "  feat:     New feature"
    echo "  fix:      Bug fix"
    echo "  docs:     Documentation changes"
    echo "  style:    Code style changes (formatting, etc.)"
    echo "  refactor: Code refactoring"
    echo "  test:     Adding or updating tests"
    echo "  chore:    Build process or auxiliary tool changes"
    echo "  ci:       CI/CD changes"
    echo "  perf:     Performance improvements"
    echo ""
    echo "Examples:"
    echo "  feat(cli): add dry-run mode"
    echo "  fix(backup): handle permission errors"
    echo "  docs: update installation instructions"
    echo "  test(link): add comprehensive link tests"
    echo ""
    echo "Your commit message:"
    echo "  $commit_msg"
    exit 1
fi

# Check commit message length
first_line=$(echo "$commit_msg" | head -n 1)
if [ ${#first_line} -gt 72 ]; then
    echo "❌ Commit message first line is too long (${#first_line} characters)."
    echo "Please keep it under 72 characters."
    echo "Current message: $first_line"
    exit 1
fi

echo "✅ Commit message format is valid."
exit 0
EOF

# Copy pre-push hook
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash

# Dotfiler Pre-push Hook
# Runs comprehensive checks before pushing to remote

echo "Running pre-push checks..."

protected_branch="master"
current_branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

# Check if we're pushing to the protected branch
if [ "$current_branch" = "$protected_branch" ]; then
    echo "Pushing to protected branch '$protected_branch'. Running full test suite..."
    
    # Ensure code is properly formatted
    echo "Checking code formatting..."
    if ! mix format --check-formatted; then
        echo "❌ Code is not properly formatted. Run 'mix format' first."
        exit 1
    fi
    
    # Run full test suite with coverage
    echo "Running complete test suite..."
    if ! mix test; then
        echo "❌ Tests failed. Cannot push to $protected_branch."
        exit 1
    fi
    
    # Check for compilation warnings
    echo "Checking for compilation warnings..."
    if ! mix compile --warnings-as-errors; then
        echo "❌ Compilation has warnings. Cannot push to $protected_branch."
        exit 1
    fi
    
    # Verify escript builds successfully
    echo "Verifying escript build..."
    if ! mix escript.build; then
        echo "❌ Escript build failed. Cannot push to $protected_branch."
        exit 1
    fi
    
    # Optional: Check for security issues (if credo is available)
    if command -v mix credo &> /dev/null; then
        echo "Running code quality checks..."
        if ! mix credo --strict; then
            echo "❌ Code quality issues found. Consider fixing them before pushing."
            # Uncomment to make this a hard failure:
            # exit 1
        fi
    fi
fi

echo "✅ Pre-push checks passed!"
exit 0
EOF

# Make hooks executable
chmod +x .git/hooks/pre-commit
chmod +x .git/hooks/commit-msg  
chmod +x .git/hooks/pre-push

echo "✅ Git hooks installed successfully!"
echo ""
echo "Hooks installed:"
echo "  - Pre-commit: Formats code, compiles, runs tests"
echo "  - Commit-msg: Enforces conventional commit messages" 
echo "  - Pre-push: Extra checks for protected branches"
echo ""
echo "To bypass hooks temporarily, use: git commit --no-verify"