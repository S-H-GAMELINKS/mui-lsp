# frozen_string_literal: true

require_relative "../test_helper"

# E2E tests using Ruby LSP (Shopify's ruby-lsp)
# These tests require ruby-lsp to be installed: gem install ruby-lsp
class TestRubyLspE2E < Minitest::Test
  FIXTURES_DIR = File.expand_path("../fixtures", __dir__)
  SAMPLE_FILE = File.join(FIXTURES_DIR, "sample.rb")
  SAMPLE_URI = "file://#{SAMPLE_FILE}"

  def setup
    skip_unless_ruby_lsp_available
    @notifications = []
    @client = Mui::Lsp::Client.new(
      command: "ruby-lsp",
      root_path: FIXTURES_DIR,
      on_notification: ->(method, params) { @notifications << { method: method, params: params } }
    )
  end

  def teardown
    @client&.stop
  end

  def test_server_initialization
    @client.start

    assert @client.running?, "Client should be running after start"
    assert @client.initialized, "Client should be initialized"
    refute_empty @client.server_capabilities, "Server should report capabilities"
  end

  def test_did_open_document
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(
      uri: SAMPLE_URI,
      language_id: "ruby",
      version: 1,
      text: text
    )

    sleep 0.5
    assert @client.running?, "Client should still be running after opening document"
  end

  def test_hover_on_class
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)
    sleep 0.5

    result = nil
    error = nil
    done = false

    # Hover over "Calculator" class (line 3, column 6)
    @client.hover(uri: SAMPLE_URI, line: 3, character: 6) do |r, e|
      result = r
      error = e
      done = true
    end

    wait_for { done }

    assert_nil error, "Hover should not return an error"
  end

  def test_completion
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)
    sleep 0.5

    result = nil
    error = nil
    done = false

    # Trigger completion
    @client.completion(uri: SAMPLE_URI, line: 20, character: 13) do |r, e|
      result = r
      error = e
      done = true
    end

    wait_for { done }

    assert_nil error, "Completion should not return an error"
  end

  def test_definition
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)
    sleep 0.5

    result = nil
    error = nil
    done = false

    # Jump to definition of Calculator (line 19)
    @client.definition(uri: SAMPLE_URI, line: 19, character: 10) do |r, e|
      result = r
      error = e
      done = true
    end

    wait_for { done }

    assert_nil error, "Definition should not return an error"
  end

  def test_did_change_document
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)
    sleep 0.3

    new_text = text.gsub("Calculator", "MyCalculator")
    @client.did_change(
      uri: SAMPLE_URI,
      version: 2,
      changes: [{ text: new_text }]
    )

    sleep 0.3
    assert @client.running?, "Client should still be running after change"
  end

  def test_server_shutdown
    @client.start
    assert @client.running?

    @client.stop
    sleep 0.5

    refute @client.running?, "Client should not be running after stop"
  end

  def test_diagnostics_received
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)

    # Wait for potential diagnostics
    sleep 1.0

    # Ruby LSP should still be running
    assert @client.running?
  end

  private

  def skip_unless_ruby_lsp_available
    result = system("which ruby-lsp > /dev/null 2>&1")
    skip "ruby-lsp not installed" unless result
  end

  def wait_for(timeout: 5)
    start = Time.now
    until yield
      sleep 0.1
      raise "Timeout waiting for condition" if Time.now - start > timeout
    end
  end
end
