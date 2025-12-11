# frozen_string_literal: true

require "test_helper"

class Mui::TestLsp < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Mui::Lsp::VERSION
  end

  def test_error_class_exists
    assert_kind_of Class, Mui::Lsp::Error
  end
end
