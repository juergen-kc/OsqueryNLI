cask "osquery-nli" do
  version "1.0.5"
  sha256 "57d8e34604903723f483c8a750ac79e7aff6251ce8de8a2c46b6faa6acc94b8f"

  url "https://github.com/juergen-kc/OsqueryNLI/releases/download/#{version}/OsqueryNLI-#{version}.dmg"
  name "Osquery NLI"
  desc "Natural language interface for osquery - ask questions about your Mac in plain English"
  homepage "https://github.com/juergen-kc/OsqueryNLI"

  depends_on macos: ">= :sonoma"

  app "OsqueryNLI.app", target: "Osquery NLI.app"

  zap trash: [
    "~/Library/Preferences/com.klaassen.OsqueryNLI.plist",
    "~/Library/Caches/com.klaassen.OsqueryNLI",
  ]

  caveats <<~EOS
    Osquery NLI requires osquery to be installed:
      brew install osquery

    You'll also need an API key from one of:
      - Google Gemini: https://makersuite.google.com/app/apikey
      - Anthropic Claude: https://console.anthropic.com/
      - OpenAI: https://platform.openai.com/api-keys
  EOS
end
