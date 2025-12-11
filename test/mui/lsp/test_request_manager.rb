# frozen_string_literal: true

require_relative "../../test_helper"

class TestRequestManager < Minitest::Test
  def setup
    @manager = Mui::Lsp::RequestManager.new
  end

  def test_register_returns_incrementing_ids
    callback = proc {}

    id1 = @manager.register(callback)
    id2 = @manager.register(callback)
    id3 = @manager.register(callback)

    assert_equal 1, id1
    assert_equal 2, id2
    assert_equal 3, id3
  end

  def test_pending?
    callback = proc {}
    id = @manager.register(callback)

    assert @manager.pending?(id)
    refute @manager.pending?(999)
  end

  def test_pending_count
    callback = proc {}

    assert_equal 0, @manager.pending_count

    @manager.register(callback)
    assert_equal 1, @manager.pending_count

    @manager.register(callback)
    assert_equal 2, @manager.pending_count
  end

  def test_handle_response_with_result
    result = nil
    error = nil

    callback = proc do |r, e|
      result = r
      error = e
    end

    id = @manager.register(callback)
    @manager.handle_response(id, result: { value: "test" })

    assert_equal({ value: "test" }, result)
    assert_nil error
    refute @manager.pending?(id)
  end

  def test_handle_response_with_error
    result = nil
    error = nil

    callback = proc do |r, e|
      result = r
      error = e
    end

    id = @manager.register(callback)
    @manager.handle_response(id, error: { code: -1, message: "Error" })

    assert_nil result
    assert_equal({ code: -1, message: "Error" }, error)
  end

  def test_handle_response_returns_false_for_unknown_id
    refute @manager.handle_response(999, result: {})
  end

  def test_cancel
    callback = proc {}
    id = @manager.register(callback)

    assert @manager.pending?(id)
    assert @manager.cancel(id)
    refute @manager.pending?(id)
    refute @manager.cancel(id) # Already cancelled
  end

  def test_cancel_all
    callback = proc {}
    id1 = @manager.register(callback)
    id2 = @manager.register(callback)

    @manager.cancel_all

    refute @manager.pending?(id1)
    refute @manager.pending?(id2)
    assert_equal 0, @manager.pending_count
  end
end
