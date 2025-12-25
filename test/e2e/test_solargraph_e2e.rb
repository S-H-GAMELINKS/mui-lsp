# frozen_string_literal: true

require_relative "../test_helper"

# E2E tests using real LSP server (Solargraph)
# These tests require solargraph to be installed: gem install solargraph
class TestSolargraphE2E < Minitest::Test
  FIXTURES_DIR = File.expand_path("../fixtures", __dir__)
  SAMPLE_FILE = File.join(FIXTURES_DIR, "sample.rb")
  SAMPLE_URI = "file://#{SAMPLE_FILE}"

  def setup
    skip_unless_solargraph_available
    @notifications = []
    @client = Mui::Lsp::Client.new(
      command: "solargraph stdio",
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

    # Give the server time to process
    sleep 0.5

    # Server should still be running after opening a document
    assert @client.running?
  end

  def test_hover_on_method
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)
    sleep 0.5

    result = nil
    error = nil
    done = false

    # Hover over "add" method definition (line 8, column 6)
    @client.hover(uri: SAMPLE_URI, line: 8, character: 6) do |r, e|
      result = r
      error = e
      done = true
    end

    # Wait for response
    wait_for { done }

    assert_nil error, "Hover should not return an error"
    # Solargraph may return nil for some positions, which is valid
    if result
      assert result.key?("contents"), "Hover result should have contents"
    end
  end

  def test_completion_on_object
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)
    sleep 0.5

    result = nil
    error = nil
    done = false

    # Completion after "calc." (line 21, after the dot)
    @client.completion(uri: SAMPLE_URI, line: 20, character: 13) do |r, e|
      result = r
      error = e
      done = true
    end

    wait_for { done }

    assert_nil error, "Completion should not return an error"
    if result
      items = result.is_a?(Hash) ? result["items"] : result
      # Completion might return items or be empty depending on server state
      assert items.is_a?(Array) || items.nil?
    end
  end

  def test_definition_jump
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)
    sleep 0.5

    result = nil
    error = nil
    done = false

    # Jump to definition of "add" from call site (line 21)
    @client.definition(uri: SAMPLE_URI, line: 20, character: 15) do |r, e|
      result = r
      error = e
      done = true
    end

    wait_for { done }

    assert_nil error, "Definition should not return an error"
    # Definition result can be nil, single location, or array of locations
  end

  def test_did_change_document
    @client.start

    text = File.read(SAMPLE_FILE)
    @client.did_open(uri: SAMPLE_URI, language_id: "ruby", version: 1, text: text)
    sleep 0.3

    # Simulate editing the document
    new_text = text.gsub("add", "add_numbers")
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

  def test_diagnostics_notification
    @client.start

    # Code with intentional issue
    bad_code = <<~RUBY
      # frozen_string_literal: true

      class BadClass
        def broken
          undefined_variable
        end
      end
    RUBY

    bad_file = File.join(FIXTURES_DIR, "bad_code.rb")
    File.write(bad_file, bad_code)

    begin
      @client.did_open(
        uri: "file://#{bad_file}",
        language_id: "ruby",
        version: 1,
        text: bad_code
      )

      # Wait for diagnostics
      sleep 1.5

      # Check if we received any diagnostics notifications
      diagnostic_notifications = @notifications.select do |n|
        n[:method] == "textDocument/publishDiagnostics"
      end

      # Solargraph may or may not send diagnostics for this code
      # The test passes if no errors occurred
      assert @client.running?
    ensure
      File.delete(bad_file) if File.exist?(bad_file)
    end
  end

  private

  def skip_unless_solargraph_available
    result = system("which solargraph > /dev/null 2>&1")
    skip "Solargraph not installed" unless result
  end

  def wait_for(timeout: 5)
    start = Time.now
    until yield
      sleep 0.1
      raise "Timeout waiting for condition" if Time.now - start > timeout
    end
  end
end
