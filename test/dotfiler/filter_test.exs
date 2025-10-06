defmodule Dotfiler.FilterTest do
  use ExUnit.Case

  alias Dotfiler.{Config, Filter}

  @tmp_dir "/tmp/dotfiler_filter_test"
  @source_dir "#{@tmp_dir}/source"

  setup do
    # Clean up any existing test directories
    File.rm_rf(@tmp_dir)

    # Create test directories
    File.mkdir_p!(@source_dir)

    on_exit(fn ->
      File.rm_rf(@tmp_dir)
    end)

    :ok
  end

  describe "Filter.new/2" do
    test "creates filter with default configuration" do
      config = Config.load()
      filter = Filter.new(config, @source_dir)

      assert filter.config == config
      assert filter.source_dir == @source_dir
      assert filter.include_patterns == ["*"]
      assert filter.exclude_patterns == [".*", "[A-Z]*"]
      assert filter.ignore_patterns == []
    end

    test "creates filter with custom include/exclude patterns" do
      config = %{
        filtering: %{
          include: ["*.conf", "*.rc"],
          exclude: ["*.tmp", "*.log"]
        }
      }

      filter = Filter.new(config, @source_dir)

      assert filter.include_patterns == ["*.conf", "*.rc"]
      assert filter.exclude_patterns == ["*.tmp", "*.log"]
    end
  end

  describe "Filter.should_process?/2" do
    test "returns false for empty filename" do
      config = Config.load()
      filter = Filter.new(config, @source_dir)

      refute Filter.should_process?(filter, "")
    end

    test "filters dotfiles by default" do
      config = Config.load()
      filter = Filter.new(config, @source_dir)

      refute Filter.should_process?(filter, ".bashrc")
      refute Filter.should_process?(filter, ".gitignore")
      assert Filter.should_process?(filter, "vimrc")
    end

    test "filters uppercase files by default" do
      config = Config.load()
      filter = Filter.new(config, @source_dir)

      refute Filter.should_process?(filter, "README")
      refute Filter.should_process?(filter, "LICENSE")
      assert Filter.should_process?(filter, "readme")
    end

    test "processes files matching include patterns when specified" do
      config = %{
        filtering: %{
          include: ["*.conf", "*.rc"],
          exclude: []
        }
      }

      filter = Filter.new(config, @source_dir)

      assert Filter.should_process?(filter, "nginx.conf")
      assert Filter.should_process?(filter, "test.rc")
      refute Filter.should_process?(filter, "bashrc")
      refute Filter.should_process?(filter, "somefile.txt")
    end

    test "excludes files matching exclude patterns" do
      config = %{
        filtering: %{
          include: ["*"],
          exclude: ["*.tmp", "*.log"]
        }
      }

      filter = Filter.new(config, @source_dir)

      refute Filter.should_process?(filter, "temp.tmp")
      refute Filter.should_process?(filter, "debug.log")
      assert Filter.should_process?(filter, "config.conf")
    end
  end

  describe ".dotfilerignore file parsing" do
    test "loads and applies dotfilerignore patterns" do
      # Create a .dotfilerignore file
      ignore_content = """
      # This is a comment
      *.tmp
      cache/
      !important.tmp
      /root-only
      """

      File.write!(Path.join(@source_dir, ".dotfilerignore"), ignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          ignore_file: ".dotfilerignore"
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should ignore *.tmp files
      refute Filter.should_process?(filter, "temp.tmp")

      # Should ignore cache/ directories
      refute Filter.should_process?(filter, "cache")

      # Should include important.tmp due to negation
      assert Filter.should_process?(filter, "important.tmp")

      # Should ignore root-only files
      refute Filter.should_process?(filter, "root-only")

      # Should process other files
      assert Filter.should_process?(filter, "config.conf")
    end

    test "handles missing dotfilerignore file gracefully" do
      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          ignore_file: ".dotfilerignore"
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should process files normally when ignore file doesn't exist
      assert Filter.should_process?(filter, "config.conf")
      assert Filter.should_process?(filter, "somefile.txt")
    end
  end

  describe ".gitignore file parsing" do
    test "loads and applies gitignore patterns when enabled" do
      # Create a .gitignore file
      gitignore_content = """
      node_modules/
      *.log
      .env
      build/
      """

      File.write!(Path.join(@source_dir, ".gitignore"), gitignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          use_gitignore: true
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should ignore patterns from .gitignore
      refute Filter.should_process?(filter, "node_modules")
      refute Filter.should_process?(filter, "debug.log")
      refute Filter.should_process?(filter, ".env")
      refute Filter.should_process?(filter, "build")

      # Should process other files
      assert Filter.should_process?(filter, "package.json")
      assert Filter.should_process?(filter, "README.md")
    end

    test "ignores gitignore when use_gitignore is false" do
      # Create a .gitignore file
      gitignore_content = """
      *.log
      """

      File.write!(Path.join(@source_dir, ".gitignore"), gitignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          use_gitignore: false
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should not apply gitignore patterns when disabled
      assert Filter.should_process?(filter, "debug.log")
    end
  end

  describe "complex pattern matching" do
    test "handles glob patterns correctly" do
      ignore_content = """
      *.tmp
      cache_*
      test_?.txt
      """

      File.write!(Path.join(@source_dir, ".dotfilerignore"), ignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          ignore_file: ".dotfilerignore"
        }
      }

      filter = Filter.new(config, @source_dir)

      # Test glob patterns
      refute Filter.should_process?(filter, "temp.tmp")
      refute Filter.should_process?(filter, "cache_files")
      refute Filter.should_process?(filter, "cache_data")
      refute Filter.should_process?(filter, "test_1.txt")
      refute Filter.should_process?(filter, "test_a.txt")

      # Should not match
      # ? matches single char
      assert Filter.should_process?(filter, "test_10.txt")
      assert Filter.should_process?(filter, "not_cache")
      assert Filter.should_process?(filter, "temp.log")
    end

    test "handles star prefix patterns correctly without normalization" do
      ignore_content = """
      *.rc
      *.conf
      """

      File.write!(Path.join(@source_dir, ".dotfilerignore"), ignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          ignore_file: ".dotfilerignore"
        }
      }

      filter = Filter.new(config, @source_dir)

      # *.rc should match files with .rc extension (dot before rc)
      refute Filter.should_process?(filter, "test.rc")
      refute Filter.should_process?(filter, "vim.rc")
      refute Filter.should_process?(filter, "bash.rc")

      # *.rc should NOT match files without .rc extension
      assert Filter.should_process?(filter, "bashrc")
      assert Filter.should_process?(filter, "vimrc")
      assert Filter.should_process?(filter, ".bashrc")
      assert Filter.should_process?(filter, ".vimrc")

      # *.conf should match files with .conf extension (dot before conf)
      refute Filter.should_process?(filter, "nginx.conf")
      refute Filter.should_process?(filter, "app.conf")

      # *.conf should NOT match files without .conf extension
      assert Filter.should_process?(filter, "gitconfig")
      assert Filter.should_process?(filter, "myconf")
      assert Filter.should_process?(filter, ".gitconfig")
    end

    test "handles directory patterns" do
      ignore_content = """
      build/
      tmp/
      """

      File.write!(Path.join(@source_dir, ".dotfilerignore"), ignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          ignore_file: ".dotfilerignore"
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should ignore directory patterns
      refute Filter.should_process?(filter, "build")
      refute Filter.should_process?(filter, "tmp")
    end

    test "handles root-relative patterns" do
      ignore_content = """
      /config
      /build
      """

      File.write!(Path.join(@source_dir, ".dotfilerignore"), ignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          ignore_file: ".dotfilerignore"
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should ignore root-relative patterns
      refute Filter.should_process?(filter, "config")
      refute Filter.should_process?(filter, "build")
    end

    test "handles negation patterns correctly" do
      ignore_content = """
      *.log
      !important.log
      temp_*
      !temp_keep
      """

      File.write!(Path.join(@source_dir, ".dotfilerignore"), ignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          ignore_file: ".dotfilerignore"
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should ignore *.log but include important.log
      refute Filter.should_process?(filter, "debug.log")
      refute Filter.should_process?(filter, "error.log")
      assert Filter.should_process?(filter, "important.log")

      # Should ignore temp_* but include temp_keep
      refute Filter.should_process?(filter, "temp_file")
      refute Filter.should_process?(filter, "temp_data")
      assert Filter.should_process?(filter, "temp_keep")
    end

    test "handles complex negation patterns with globs and directories" do
      ignore_content = """
      *.log
      !important*.log
      build/
      !build_config/
      /root*
      !/root_important
      """

      File.write!(Path.join(@source_dir, ".dotfilerignore"), ignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: [],
          ignore_file: ".dotfilerignore"
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should ignore *.log but include important*.log (glob negation)
      refute Filter.should_process?(filter, "debug.log")
      refute Filter.should_process?(filter, "error.log")
      assert Filter.should_process?(filter, "important.log")
      assert Filter.should_process?(filter, "important_app.log")
      assert Filter.should_process?(filter, "important_debug.log")

      # Should ignore build/ but include build_config/ (directory negation)
      refute Filter.should_process?(filter, "build")
      assert Filter.should_process?(filter, "build_config")

      # Should ignore /root* but include /root_important (root-relative negation)
      refute Filter.should_process?(filter, "root_dir")
      refute Filter.should_process?(filter, "root_file")
      assert Filter.should_process?(filter, "root_important")
    end
  end

  describe "combined filtering rules" do
    test "applies all filtering rules in correct priority" do
      # Create ignore files
      ignore_content = """
      *.tmp
      cache/
      """

      File.write!(Path.join(@source_dir, ".dotfilerignore"), ignore_content)

      gitignore_content = """
      node_modules/
      *.log
      """

      File.write!(Path.join(@source_dir, ".gitignore"), gitignore_content)

      config = %{
        filtering: %{
          include: ["*"],
          exclude: ["[A-Z]*"],
          ignore_file: ".dotfilerignore",
          use_gitignore: true
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should be excluded by ignore files
      # .dotfilerignore
      refute Filter.should_process?(filter, "temp.tmp")
      # .dotfilerignore
      refute Filter.should_process?(filter, "cache")
      # .gitignore
      refute Filter.should_process?(filter, "node_modules")
      # .gitignore
      refute Filter.should_process?(filter, "debug.log")

      # Should be excluded by exclude patterns
      # exclude [A-Z]*
      refute Filter.should_process?(filter, "README")
      # exclude [A-Z]*
      refute Filter.should_process?(filter, "LICENSE")

      # Should be included
      assert Filter.should_process?(filter, "config.conf")
      assert Filter.should_process?(filter, "vimrc")
      assert Filter.should_process?(filter, "bashrc")
    end

    test "respects include patterns when not wildcard" do
      config = %{
        filtering: %{
          include: ["*.conf", "*.rc"],
          exclude: [],
          ignore_file: nil,
          use_gitignore: false
        }
      }

      filter = Filter.new(config, @source_dir)

      # Should only include files matching include patterns
      assert Filter.should_process?(filter, "nginx.conf")
      assert Filter.should_process?(filter, "test.rc")
      assert Filter.should_process?(filter, "vim.rc")

      # Should exclude files not matching include patterns
      refute Filter.should_process?(filter, "bashrc")
      refute Filter.should_process?(filter, "vimrc")
      refute Filter.should_process?(filter, "README.md")
      refute Filter.should_process?(filter, "package.json")
      refute Filter.should_process?(filter, "somefile.txt")
    end
  end
end
