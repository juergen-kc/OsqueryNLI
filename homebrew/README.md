# Homebrew Tap Setup

This folder contains the Homebrew Cask formula for Osquery NLI.

## Setting Up Your Tap

1. Create a new GitHub repository named `homebrew-tap`:
   ```
   https://github.com/juergen-kc/homebrew-tap
   ```

2. Add the `Casks` folder structure:
   ```
   homebrew-tap/
   └── Casks/
       └── osquery-nli.rb
   ```

3. Copy `osquery-nli.rb` to `Casks/osquery-nli.rb` in that repo

4. Push to GitHub

## User Installation

Once the tap is set up, users can install with:

```bash
# Add your tap
brew tap juergen-kc/tap

# Install Osquery NLI
brew install --cask osquery-nli

# Also install osquery if needed
brew install osquery
```

## Updating the Formula

When releasing a new version:

1. Update `version` in `osquery-nli.rb`
2. Calculate new SHA256: `shasum -a 256 OsqueryNLI-X.X.X.dmg`
3. Update `sha256` in the formula
4. Commit and push to the tap repo
