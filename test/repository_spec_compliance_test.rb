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
    docs/runbooks
  ].freeze

  REQUIRED_TEST_FILES = %w[
    test/models/organization_test.rb
    test/models/membership_test.rb
    test/models/fiscal_profile_test.rb
    test/models/customer_test.rb
    test/models/service_invoice_test.rb
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
  ].freeze

  REQUIRED_CI_CHECKS = [
    "bin/rubocop",
    "bundle exec bundler-audit check --update",
    "bundle exec brakeman --quiet --no-pager --exit-on-warn --exit-on-error",
    "bin/rails test",
    "npx @redocly/cli@latest lint openapi.yaml",
    "postgres:16",
    "docker build -t fiscalbridge-ci .",
    "actions/upload-artifact@v4"
  ].freeze

  REQUIRED_COMMIT_PATTERN = /\A(?:build|chore|ci|docs|feat|fix|perf|refactor|revert|style|test)(?:\([^)]+\))?: .+\z/
  REQUIRED_SCENARIOS = %w[smoke load stress spike].freeze

  test "keeps mandatory documentation structure and entrypoint files" do
    REQUIRED_DIRECTORIES.each do |directory|
      assert_path_exists directory
      assert File.directory?(absolute_path(directory)), "#{directory} must remain a directory"
    end

    %w[
      README.md
      openapi.yaml
      db/schema.sqlite.rb
      config/authorization_matrix.yml
      docs/api/http-examples.md
      docs/api/error-format.md
      docs/benchmarks/methodology.md
      docs/benchmarks/local-baseline.md
      docs/adr/003-postgresql-primary.md
      docs/runbooks/common-issues.md
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

  test "keeps PostgreSQL as primary verified database with SQLite fallback" do
    database_config = read_file("config/database.yml")
    docker_compose = read_file("docker-compose.yml")
    adr = read_file("docs/adr/003-postgresql-primary.md")

    assert_includes database_config, "adapter: postgresql"
    assert_includes database_config, "DATABASE_ADAPTER"
    assert_includes database_config, "adapter: sqlite3"
    assert_includes database_config, "schema_dump: schema.sqlite.rb"
    assert_includes database_config, "fiscalbridge_test"
    assert_includes docker_compose, "postgres:16"
    assert_includes adr, "PostgreSQL as the default database"
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
      db:drop
      db:create
      db:migrate
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
