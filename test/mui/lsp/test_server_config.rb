# frozen_string_literal: true

require_relative "../../test_helper"

class TestServerConfig < Minitest::Test
  def test_solargraph_config
    config = Mui::Lsp::ServerConfig.solargraph

    assert_equal "solargraph", config.name
    assert_equal "solargraph stdio", config.command
    assert_includes config.language_ids, "ruby"
    refute config.auto_start # auto_start defaults to false
  end

  def test_ruby_lsp_config
    config = Mui::Lsp::ServerConfig.ruby_lsp

    assert_equal "ruby-lsp", config.name
    assert_equal "ruby-lsp", config.command
    assert_includes config.language_ids, "ruby"
  end

  def test_kanayago_config
    config = Mui::Lsp::ServerConfig.kanayago

    assert_equal "kanayago", config.name
    assert_equal "kanayago --lsp", config.command
  end

  def test_rubocop_lsp_config
    config = Mui::Lsp::ServerConfig.rubocop_lsp

    assert_equal "rubocop", config.name
    assert_equal "rubocop --lsp", config.command
  end

  def test_handles_file
    config = Mui::Lsp::ServerConfig.solargraph

    assert config.handles_file?("app/models/user.rb")
    assert config.handles_file?("lib/tasks/task.rake")
    assert config.handles_file?("Gemfile")
    refute config.handles_file?("index.js")
    refute config.handles_file?("main.py")
  end

  def test_language_id_for
    config = Mui::Lsp::ServerConfig.solargraph

    assert_equal "ruby", config.language_id_for("test.rb")
    assert_equal "ruby", config.language_id_for("Rakefile.rake")
    assert_equal "javascript", config.language_id_for("index.js")
    assert_equal "python", config.language_id_for("main.py")
  end

  def test_custom_config
    config = Mui::Lsp::ServerConfig.custom(
      name: "my-lsp",
      command: "my-lsp --stdio",
      language_ids: ["mylang"],
      file_patterns: ["**/*.ml"],
      auto_start: false
    )

    assert_equal "my-lsp", config.name
    assert_equal "my-lsp --stdio", config.command
    assert_includes config.language_ids, "mylang"
    refute config.auto_start
  end

  def test_to_h
    config = Mui::Lsp::ServerConfig.solargraph(auto_start: true)
    hash = config.to_h

    assert_equal "solargraph", hash[:name]
    assert_equal "solargraph stdio", hash[:command]
    assert hash[:auto_start]
  end
end
