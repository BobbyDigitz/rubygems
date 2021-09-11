# frozen_string_literal: true
require_relative 'helper'
require 'rubygems/commands/build_command'
require 'rubygems/commands/rebuild_command'
require 'rubygems/package'

class TestGemCommandsRebuildCommand < Gem::TestCase
  def setup
    super

    readme_file = File.join(@tempdir, 'README.md')

    begin
      umask_orig = File.umask(2)
      File.open readme_file, 'w' do |f|
        f.write 'My awesome gem'
      end
    ensure
      File.umask(umask_orig)
    end

    @gem_name = "rebuild_test_gem"
    @gem_version = "1.0.0"
    @gem = util_spec @gem_name do |s|
      s.version = @gem_version
      s.license = 'AGPL-3.0'
      s.files = ['README.md']
    end

    @build_cmd = Gem::Commands::BuildCommand.new
    @rebuild_cmd = Gem::Commands::RebuildCommand.new
  end

  def util_test_build_gem(gem, args)
    @ui = Gem::MockGemUi.new

    @build_cmd.options[:args] = args
    use_ui @ui do
      Dir.chdir @tempdir do
        @build_cmd.execute
      end
    end
    gem_file = "#{@gem_name}-#{@gem_version}.gem"
    output = @ui.output.split "\n"
    assert_equal "  Successfully built RubyGem", output.shift
    assert_equal "  Name: #{@gem_name}", output.shift
    assert_equal "  Version: #{@gem_version}", output.shift
    assert_equal "  File: #{gem_file}", output.shift
    assert_equal [], output

    gem_file = File.join(@tempdir, gem_file)
    assert File.exist?(gem_file)

    spec = Gem::Package.new(gem_file).spec

    assert_equal @gem_name, spec.name
    assert_equal "this is a summary", spec.summary
    spec
  end

  def util_test_rebuild_gem(gem, args)
    @ui = Gem::MockGemUi.new

    @rebuild_cmd.options[:args] = args
    use_ui @ui do
      Dir.chdir @tempdir do
        @rebuild_cmd.execute
      end
    end
    gem_file = "#{@gem_name}.gem"
    output = @ui.output.split "\n"
    assert_nil output
    assert_equal "  Successfully built RubyGem", output.shift
    assert_equal "  Name: #{@gem_name}", output.shift
    assert_equal "  Version: #{@gem_version}", output.shift
    assert_equal "  File: #{gem_file}", output.shift
    assert_equal [], output

    gem_file = File.join(@tempdir, gem_file)
    assert File.exist?(gem_file)

    spec = Gem::Package.new(gem_file).spec

    assert_equal @gem_name, spec.name
    assert_equal "this is a summary", spec.summary
    [spec, gem_file]
  end

  def test_build_is_reproducible
    # Back up SOURCE_DATE_EPOCH to restore later.
    epoch = ENV["SOURCE_DATE_EPOCH"]

    gem_file = File.basename(@gem.cache_file)
    gemspec_file = File.join(@tempdir, @gem.spec_name)

    # Initial Build

    new_epoch = Time.now.to_i.to_s
    ENV["SOURCE_DATE_EPOCH"] = new_epoch
    File.write(gemspec_file, @gem.to_ruby)
    util_test_build_gem @gem, [gemspec_file]

    build_contents = File.read(gem_file)
    File.delete(gem_file)

    # Guarantee the time has changed.
    sleep 1 if Time.now.to_i == new_epoch

    # Rebuild

    # Unset SOURCE_DATE_EPOCH
    ENV.delete("SOURCE_DATE_EPOCH")

    # TODO: Figure out how to add ['--original', gem_file]
    _rebuild_spec, rebuild_gem_file = util_test_rebuild_gem @gem, [@gem_name, @gem_version]

    rebuild_contents = File.read(rebuild_gem_file)

    assert_equal build_contents, rebuild_contents
  ensure
    ENV["SOURCE_DATE_EPOCH"] = epoch
  end
end
