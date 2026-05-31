require "test_helper"
require "json"
require "open3"
require "yaml"

class RepositorySpecComplianceTest < ActiveSupport::TestCase
  README_SECTION_HEADINGS = [
    "## 1. What is this product?",
    "## 2. Problem it solves",
    "## 3. Target users",
    "## 4. Main features",
    "## 5. Architecture overview",
    "## 6. Tech stack",
    "## 7. Domain model",
    "## 8. API documentation",
    "## 9. Async or event architecture",
    "## 10. Database design",
    "## 11. Testing strategy",
    "## 12. Performance benchmarks",
    "## 13. Observability",
    "## 14. Security considerations",
    "## 15. Trade-offs and decisions",
    "## 16. How to run locally",
    "## 17. How to run tests",
    "## 18. Failure scenarios",
    "## 19. Roadmap"
  ].freeze

  REQUIRED_DIRECTORIES = %w[
    docs/adr
    docs/architecture
    docs/benchmarks
    docs/api
    docs/diagrams
    docs/events
    docs/implementation
    docs/runbooks
    docs/security
  ].freeze

  REQUIRED_TEST_FILES = %w[
    test/models/organization_test.rb
    test/models/membership_test.rb
    test/models/fiscal_profile_test.rb
    test/models/customer_test.rb
    test/models/service_invoice_test.rb
    test/models/session_test.rb
    test/models/provider_request_test.rb
    test/integration/organizations_flow_test.rb
    test/integration/service_invoices_flow_test.rb
    test/integration/authorization_and_isolation_test.rb
    test/integration/failure_scenarios_test.rb
    test/integration/membership_token_lifecycle_test.rb
    test/integration/openapi_response_contract_test.rb
    test/integration/rate_limiting_and_metrics_test.rb
    test/jobs/outbound_event_dispatch_job_test.rb
    test/jobs/service_invoice_jobs_test.rb
    test/services/mutation_transaction_boundaries_test.rb
    test/services/security_authorizer_test.rb
    test/services/invoice_sequence_test.rb
    test/services/events_publisher_contract_test.rb
    test/services/provider_adapter_contract_test.rb
    test/system/backoffice_authentication_test.rb
    test/system/backoffice_service_invoices_test.rb
  ].freeze

  REQUIRED_CI_CHECKS = [
    "bin/rubocop",
    "bundle exec bundler-audit check --update",
    "bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error",
    "bin/rails test",
    "bin/rails test:system",
    "npx @redocly/cli@latest lint openapi.yaml",
    "postgres:16",
    "docker build -t fiscalbridge-ci .",
    "actions/upload-artifact@v4"
  ].freeze

  REQUIRED_COMMIT_PATTERN = /\A(?:build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(?:\([^)]+\))?: .+\z/
  REQUIRED_SCENARIOS = %w[smoke load stress spike].freeze
  REQUIRED_EVENT_ENVELOPE_FIELDS = %w[
    event_id
    event_type
    schema_version
    occurred_at
    producer
    organization_id
    service_invoice_id
    correlation_id
    provider
    environment
    payload
  ].freeze

  test "keeps mandatory documentation structure and entrypoint files" do
    REQUIRED_DIRECTORIES.each do |directory|
      assert_path_exists directory
      assert File.directory?(absolute_path(directory)), "#{directory} must remain a directory"
    end

    %w[
      README.md
      openapi.yaml
      db/schema.rb
      config/authorization_matrix.yml
      config/deploy.yml
      docs/api/http-examples.md
      docs/api/error-format.md
      docs/benchmarks/methodology.md
      docs/benchmarks/local-baseline.md
      docs/adr/003-postgresql-primary.md
      docs/adr/004-hybrid-rails-dhh-stack.md
      docs/adr/005-provider-ports-and-adapters.md
      docs/architecture/deployment-readiness.md
      docs/events/README.md
      docs/events/service_invoice_cancelled.v1.json
      docs/events/service_invoice_created.v1.json
      docs/events/service_invoice_issued.v1.json
      docs/events/service_invoice_rejected.v1.json
      docs/implementation/dhh-hybrid-migration-plan.md
      docs/runbooks/common-issues.md
      docs/runbooks/provider-contract-drift.md
      docs/security/fiscal-threat-model.md
      docs/security/production-hardening-tradeoffs.md
    ].each { |path| assert_path_exists path }
  end

  test "keeps README sections required by the repository spec in order" do
    readme = read_file("README.md")
    previous_index = -1

    README_SECTION_HEADINGS.each do |heading|
      current_index = readme.index(heading)

      assert current_index, "README.md must include #{heading.inspect}"
      assert_operator current_index, :>, previous_index, "#{heading.inspect} must remain ordered"

      previous_index = current_index
    end
  end

  test "keeps HTTP API baseline artifacts and examples" do
    openapi = YAML.safe_load(read_file("openapi.yaml"), aliases: true)
    paths = openapi.fetch("paths")
    security_scheme = openapi.dig("components", "securitySchemes", "BearerAuth")
    responses = openapi.fetch("components").fetch("responses")
    http_examples = read_file("docs/api/http-examples.md")
    error_format = read_file("docs/api/error-format.md")

    assert_equal "3.1.0", openapi.fetch("openapi")
    assert_includes paths.keys, "/v1/organizations"
    assert_includes paths.keys, "/v1/organization"
    assert_includes paths.keys, "/v1/memberships"
    assert_includes paths.keys, "/v1/fiscal_profiles"
    assert_includes paths.keys, "/v1/customers"
    assert_includes paths.keys, "/v1/service_invoices"
    assert paths.keys.any? { |path| path.match?(%r{\A/v1/}) }, "OpenAPI paths must remain versioned"

    assert_equal "http", security_scheme.fetch("type")
    assert_equal "bearer", security_scheme.fetch("scheme")

    %w[Unauthorized Forbidden ValidationFailed RateLimited Conflict].each do |response_name|
      assert responses.key?(response_name), "OpenAPI components.responses must include #{response_name}"
    end

    assert_includes http_examples, "Authorization: Bearer"
    assert_includes http_examples, "## Validation failure example"
    assert_includes http_examples, "## Authorization failure example"
    assert_includes http_examples, "## Tenant-isolation failure example"

    %w[missing_parameter unauthorized forbidden not_found conflict validation_failed rate_limited missing_idempotency_key].each do |code|
      assert_includes error_format, code
    end
  end

  test "keeps CI workflow checks required by the repository spec" do
    workflow = read_file(".github/workflows/ci.yml")
    REQUIRED_CI_CHECKS.each { |check| assert_includes workflow, check }
  end

  test "keeps PostgreSQL as the verified database and Solid as Rails runtime foundation" do
    database_config = read_file("config/database.yml")
    application_config = read_file("config/application.rb")
    gemfile = read_file("Gemfile")
    docker_compose = read_file("docker-compose.yml")
    adr = read_file("docs/adr/003-postgresql-primary.md")
    hybrid_adr = read_file("docs/adr/004-hybrid-rails-dhh-stack.md")

    assert_includes database_config, "adapter: postgresql"
    assert_includes database_config, "primary:"
    assert_includes database_config, "fiscalbridge_test"
    refute_includes database_config, "adapter: sqlite3"
    assert_includes docker_compose, "postgres:16"
    assert_includes adr, "PostgreSQL as the default database"
    assert_includes hybrid_adr, "hybrid Rails monolith"

    %w[solid_queue solid_cache solid_cable propshaft importmap-rails turbo-rails stimulus-rails].each do |gem_name|
      assert_includes gemfile, gem_name
    end

    assert_includes application_config, "config.active_job.queue_adapter = :solid_queue"
    assert_includes application_config, "config.cache_store = :solid_cache_store"
  end

  test "keeps durable outbox production mechanics executable" do
    migration = read_file("db/migrate/20260529100000_create_fiscalbridge_core.rb")
    recurring = read_file("config/recurring.yml")
    dispatch_job = read_file("app/jobs/outbound_event_dispatch_job.rb")

    assert_includes migration, "t.bigint :aggregate_id"
    assert_includes recurring, "DispatchDueOutboundEventsJob"
    assert_includes dispatch_job, "claim_event(outbound_event_id)"
    assert_includes dispatch_job, "set(wait_until: next_attempt_at).perform_later(event.id)"
  end

  test "keeps security observability and data consistency artifacts" do
    threat_model = read_file("docs/security/threat-model.md")
    authorization_matrix = read_file("docs/security/authorization-matrix.md")
    data_consistency = read_file("docs/architecture/data-consistency.md")
    grafana_dashboard = JSON.parse(read_file("docs/diagrams/grafana-fiscalbridge-overview.json"))

    [ "Scope", "Trust boundaries", "Primary threats", "Tests mapped to threats" ].each do |phrase|
      assert_includes threat_model, phrase
    end

    %w[owner admin operator auditor service_invoices_create service_invoices_issue].each do |phrase|
      assert_includes authorization_matrix, phrase
    end

    [
      "Transaction boundaries",
      "Indexes and constraints",
      "Optimistic locking",
      "Isolation assumptions",
      "Migration strategy",
      "Rollback strategy"
    ].each { |heading| assert_includes data_consistency, heading }

    assert_operator grafana_dashboard.fetch("panels").length, :>, 0
  end

  test "keeps fiscal provider architecture and event contracts aligned" do
    provider_adr = read_file("docs/adr/005-provider-ports-and-adapters.md")
    fiscal_threat_model = read_file("docs/security/fiscal-threat-model.md")
    event_contracts = read_file("docs/events/README.md")
    event_schema_paths = Dir[absolute_path("docs/events/*.v1.json")].sort

    %w[issue cancel fetch_status download_xml download_pdf ProviderResult ProviderDocument].each do |term|
      assert_includes provider_adr, term
    end

    [
      "Duplicate issuance",
      "False callback",
      "XML/PDF leakage",
      "Audit log tampering",
      "Homologation/production"
    ].each { |term| assert_includes fiscal_threat_model, term }

    REQUIRED_EVENT_ENVELOPE_FIELDS.each { |field| assert_includes event_contracts, "`#{field}`" }
    assert_operator event_schema_paths.length, :>=, 4

    event_schema_paths.each do |schema_path|
      schema = JSON.parse(File.read(schema_path))
      required = schema.fetch("required")
      properties = schema.fetch("properties")
      basename = File.basename(schema_path)
      parts = basename.delete_suffix(".v1.json").split("_")
      expected_event_type = "#{parts.first(2).join('_')}.#{parts.drop(2).join('_')}"

      REQUIRED_EVENT_ENVELOPE_FIELDS.each do |field|
        assert_includes required, field, "#{basename} must require #{field}"
        assert properties.key?(field), "#{basename} must define property #{field}"
      end

      assert_equal expected_event_type, properties.fetch("event_type").fetch("const")
      assert_equal 1, properties.fetch("schema_version").fetch("const")
      assert_equal %w[sandbox homologation production], properties.fetch("environment").fetch("enum")
      assert_equal false, schema.fetch("additionalProperties")
      assert_includes event_contracts, basename
    end
  end

  test "keeps benchmark scenarios measured artifacts and required metrics evidence" do
    baseline = read_file("benchmarks/baseline.md")
    local_baseline = read_file("docs/benchmarks/local-baseline.md")

    assert_path_exists "benchmarks/baseline.md"
    assert_path_exists "benchmarks/lib/fiscalbridge.js"
    assert_path_exists "benchmarks/results/README.md"
    assert_path_exists "bin/benchmark"

    %w[p50 p95 p99 Throughput Error rate].each { |metric_label| assert_includes local_baseline, metric_label }
    assert_includes local_baseline, "CPU"
    assert_includes local_baseline, "RSS"

    benchmark_runner = read_file("bin/benchmark")
    %w[
      BENCHMARK_RAILS_ENV
      db:migrate:reset
      wait_for_ready!
      server
      resource-samples
      RATE_LIMIT_REQUESTS_PER_MINUTE
    ].each { |term| assert_includes benchmark_runner, term }

    REQUIRED_SCENARIOS.each do |scenario|
      assert_includes baseline.downcase, scenario
      assert_includes local_baseline, scenario.capitalize
      assert_path_exists "benchmarks/#{scenario}.js"
      assert_path_exists "benchmarks/results/#{scenario}-summary.txt"
      assert_path_exists "benchmarks/results/#{scenario}-summary.json"
      assert_path_exists "benchmarks/results/#{scenario}-resource-samples.tsv"

      summary = JSON.parse(read_file("benchmarks/results/#{scenario}-summary.json"))
      metrics = summary.fetch("metrics")

      assert metrics.key?("http_req_duration"), "#{scenario} summary must expose http_req_duration"
      assert metrics.key?("http_req_failed"), "#{scenario} summary must expose http_req_failed"
      assert metrics.key?("http_reqs"), "#{scenario} summary must expose throughput data"
      assert metrics.fetch("http_req_duration").key?("p(95)")
      assert metrics.fetch("http_req_duration").key?("p(99)")
    end
  end

  test "keeps explicit test coverage for critical repository layers" do
    REQUIRED_TEST_FILES.each { |path| assert_path_exists path }
  end

  test "uses conventional commits when git history is available" do
    skip "git metadata is not available in this environment" unless File.directory?(absolute_path(".git"))
    skip "git executable is not available in this environment" unless File.executable?("/usr/bin/git")

    stdout, stderr, status = Open3.capture3("/usr/bin/git", "log", "--format=%s", "--no-merges")

    assert status.success?, "git log failed: #{stderr}"

    subjects = stdout.lines.map(&:strip).reject(&:empty?)
    assert subjects.any?, "git history must contain at least one commit subject"

    subjects.each do |subject|
      assert_match REQUIRED_COMMIT_PATTERN, subject, "Commit subject must follow Conventional Commits: #{subject.inspect}"
    end
  end

  private

  def read_file(relative_path)
    File.read(absolute_path(relative_path))
  end

  def absolute_path(relative_path)
    Rails.root.join(relative_path)
  end

  def assert_path_exists(relative_path)
    assert File.exist?(absolute_path(relative_path)), "#{relative_path} must exist"
  end
end
