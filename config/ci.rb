# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bundle exec bundler-audit check --update"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  step "Contract: OpenAPI", "npx @redocly/cli@latest lint openapi.yaml"
  step "Tests: Rails", "env POSTGRES_STATEMENT_TIMEOUT_MS=0 RAILS_ENV=test bin/rails db:drop db:create db:migrate test"
  step "Tests: System", "env POSTGRES_STATEMENT_TIMEOUT_MS=0 RAILS_ENV=test bin/rails test:system"
  step "Tests: Seeds", "env POSTGRES_STATEMENT_TIMEOUT_MS=0 RAILS_ENV=test bin/rails db:seed:replant"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
