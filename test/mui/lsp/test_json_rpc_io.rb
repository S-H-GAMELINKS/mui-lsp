# frozen_string_literal: true

require_relative "../../test_helper"
require "stringio"

class TestJsonRpcIO < Minitest::Test
  def test_build_request
    message = Mui::Lsp::JsonRpcIO.build_request(
      id: 1,
      method: "textDocument/hover",
      params: { textDocument: { uri: "file:///test.rb" } }
    )

    assert_equal "2.0", message[:jsonrpc]
    assert_equal 1, message[:id]
    assert_equal "textDocument/hover", message[:method]
    assert_equal({ textDocument: { uri: "file:///test.rb" } }, message[:params])
  end

  def test_build_notification
    message = Mui::Lsp::JsonRpcIO.build_notification(
      method: "initialized",
      params: {}
    )

    assert_equal "2.0", message[:jsonrpc]
    refute message.key?(:id)
    assert_equal "initialized", message[:method]
  end

  def test_build_response
    message = Mui::Lsp::JsonRpcIO.build_response(
      id: 1,
      result: { contents: "Hello" }
    )

    assert_equal "2.0", message[:jsonrpc]
    assert_equal 1, message[:id]
    assert_equal({ contents: "Hello" }, message[:result])
  end

  def test_build_error_response
    message = Mui::Lsp::JsonRpcIO.build_error_response(
      id: 1,
      code: -32_600,
      message: "Invalid Request"
    )

    assert_equal "2.0", message[:jsonrpc]
    assert_equal 1, message[:id]
    assert_equal(-32_600, message[:error][:code])
    assert_equal "Invalid Request", message[:error][:message]
  end

  def test_request?
    request = { "id" => 1, "method" => "test" }
    notification = { "method" => "test" }
    response = { "id" => 1, "result" => nil }

    assert Mui::Lsp::JsonRpcIO.request?(request)
    refute Mui::Lsp::JsonRpcIO.request?(notification)
    refute Mui::Lsp::JsonRpcIO.request?(response)
  end

  def test_notification?
    request = { "id" => 1, "method" => "test" }
    notification = { "method" => "test" }
    response = { "id" => 1, "result" => nil }

    refute Mui::Lsp::JsonRpcIO.notification?(request)
    assert Mui::Lsp::JsonRpcIO.notification?(notification)
    refute Mui::Lsp::JsonRpcIO.notification?(response)
  end

  def test_response?
    request = { "id" => 1, "method" => "test" }
    notification = { "method" => "test" }
    response = { "id" => 1, "result" => nil }
    error_response = { "id" => 1, "error" => { "code" => -1, "message" => "Error" } }

    refute Mui::Lsp::JsonRpcIO.response?(request)
    refute Mui::Lsp::JsonRpcIO.response?(notification)
    assert Mui::Lsp::JsonRpcIO.response?(response)
    assert Mui::Lsp::JsonRpcIO.response?(error_response)
  end

  def test_write_and_read_message
    input = StringIO.new
    output = StringIO.new

    io = Mui::Lsp::JsonRpcIO.new(input: input, output: output)

    # Write a message
    io.write_message({ jsonrpc: "2.0", id: 1, method: "test" })

    # Read it back
    output.rewind
    input_io = Mui::Lsp::JsonRpcIO.new(input: output, output: StringIO.new)
    message = input_io.read_message

    assert_equal "2.0", message["jsonrpc"]
    assert_equal 1, message["id"]
    assert_equal "test", message["method"]
  end
end
