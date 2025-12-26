# frozen_string_literal: true

require_relative "../../test_helper"

class MockEditor
  attr_accessor :message

  def initialize
    @message = nil
  end
end

class TestManager < Minitest::Test
  def setup
    @editor = MockEditor.new
    @manager = Mui::Lsp::Manager.new(editor: @editor)
  end

  def test_merge_locations_with_arrays
    results = [
      [{ "uri" => "file:///a.rb", "range" => { "start" => { "line" => 1 } } }],
      [{ "uri" => "file:///b.rb", "range" => { "start" => { "line" => 2 } } }]
    ]

    merged = @manager.send(:merge_locations, results)

    assert_equal 2, merged.size
    assert_equal "file:///a.rb", merged[0]["uri"]
    assert_equal "file:///b.rb", merged[1]["uri"]
  end

  def test_merge_locations_with_hash
    results = [
      { "uri" => "file:///a.rb", "range" => { "start" => { "line" => 1 } } }
    ]

    merged = @manager.send(:merge_locations, results)

    assert_equal 1, merged.size
    assert_equal "file:///a.rb", merged[0]["uri"]
  end

  def test_merge_locations_deduplicates
    loc = { "uri" => "file:///a.rb", "range" => { "start" => { "line" => 1 } } }
    results = [[loc], [loc.dup]]

    merged = @manager.send(:merge_locations, results)

    assert_equal 1, merged.size
  end

  def test_merge_locations_with_location_link
    results = [
      [{ "targetUri" => "file:///a.rb", "targetSelectionRange" => { "start" => { "line" => 1 } } }]
    ]

    merged = @manager.send(:merge_locations, results)

    assert_equal 1, merged.size
    assert_equal "file:///a.rb", merged[0]["targetUri"]
  end

  def test_merge_locations_with_empty_results
    results = [[], nil, []]

    merged = @manager.send(:merge_locations, results.compact)

    assert_equal 0, merged.size
  end

  def test_find_rbs_file
    Dir.mktmpdir do |dir|
      # Create directory structure
      FileUtils.mkdir_p(File.join(dir, "lib", "mui"))
      FileUtils.mkdir_p(File.join(dir, "sig", "mui"))
      FileUtils.touch(File.join(dir, ".git"))

      ruby_file = File.join(dir, "lib", "mui", "config.rb")
      rbs_file = File.join(dir, "sig", "mui", "config.rbs")

      FileUtils.touch(ruby_file)
      FileUtils.touch(rbs_file)

      result = @manager.send(:find_rbs_file, ruby_file)

      assert_equal rbs_file, result
    end
  end

  def test_find_rbs_file_with_lib_prefix
    Dir.mktmpdir do |dir|
      # Create directory structure
      FileUtils.mkdir_p(File.join(dir, "lib", "mui"))
      FileUtils.mkdir_p(File.join(dir, "sig", "lib", "mui"))
      FileUtils.touch(File.join(dir, ".git"))

      ruby_file = File.join(dir, "lib", "mui", "config.rb")
      rbs_file = File.join(dir, "sig", "lib", "mui", "config.rbs")

      FileUtils.touch(ruby_file)
      FileUtils.touch(rbs_file)

      result = @manager.send(:find_rbs_file, ruby_file)

      assert_equal rbs_file, result
    end
  end

  def test_find_rbs_file_not_found
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "lib"))
      FileUtils.touch(File.join(dir, ".git"))

      ruby_file = File.join(dir, "lib", "config.rb")
      FileUtils.touch(ruby_file)

      result = @manager.send(:find_rbs_file, ruby_file)

      assert_nil result
    end
  end

  def test_find_ruby_file
    Dir.mktmpdir do |dir|
      # Create directory structure
      FileUtils.mkdir_p(File.join(dir, "lib", "mui"))
      FileUtils.mkdir_p(File.join(dir, "sig", "mui"))
      FileUtils.touch(File.join(dir, ".git"))

      ruby_file = File.join(dir, "lib", "mui", "config.rb")
      rbs_file = File.join(dir, "sig", "mui", "config.rbs")

      FileUtils.touch(ruby_file)
      FileUtils.touch(rbs_file)

      result = @manager.send(:find_ruby_file, rbs_file)

      assert_equal ruby_file, result
    end
  end

  def test_find_ruby_file_not_found
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "sig"))
      FileUtils.touch(File.join(dir, ".git"))

      rbs_file = File.join(dir, "sig", "config.rbs")
      FileUtils.touch(rbs_file)

      result = @manager.send(:find_ruby_file, rbs_file)

      assert_nil result
    end
  end
end
