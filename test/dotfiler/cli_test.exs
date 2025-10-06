defmodule Dotfiler.CLITest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Dotfiler.CLI

  @tmp_dir "/tmp/dotfiler_cli_test"
  @source_dir "#{@tmp_dir}/source"

  setup do
    File.rm_rf(@tmp_dir)
    File.mkdir_p!(@source_dir)
    File.write!("#{@source_dir}/bashrc", "# test bashrc")

    # Mock System.user_home to use test directory
    original_user_home = System.get_env("HOME")
    System.put_env("HOME", @source_dir)

    on_exit(fn ->
      File.rm_rf(@tmp_dir)

      if original_user_home do
        System.put_env("HOME", original_user_home)
      else
        System.delete_env("HOME")
      end
    end)

    :ok
  end

  describe "parse/1" do
    test "shows help when no arguments provided" do
      output =
        capture_io(fn ->
          CLI.parse([])
        end)

      assert output =~ "Usage:"
      assert output =~ "<source_directory>"
    end

    test "shows help with --help flag" do
      output =
        capture_io(fn ->
          CLI.parse(["--help"])
        end)

      assert output =~ "Usage:"
      assert output =~ "--dry-run"
    end

    test "shows version with --version flag" do
      output =
        capture_io(fn ->
          CLI.parse(["--version"])
        end)

      assert output =~ "0.1.0"
    end

    test "handles restore flag" do
      output =
        capture_io(fn ->
          CLI.parse(["--restore"])
        end)

      assert output =~ "No backup log found"
    end

    test "handles dry run mode" do
      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--dry-run"])
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "[DRY RUN]"
    end

    test "handles dry run mode with brew flag" do
      File.write!("#{@source_dir}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--brew", "--dry-run"])
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "[DRY RUN]"
      assert output =~ "Would install Homebrew packages"
    end

    test "handles source directory with brew flag" do
      File.write!("#{@source_dir}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--brew"])
        end)

      # Should attempt to install Homebrew packages and link files
      assert output =~ "Installing Homebrew packages" or output =~ "No Brewfile found"
    end

    test "handles short flag variations" do
      output =
        capture_io(fn ->
          CLI.parse(["-h"])
        end)

      assert output =~ "Usage:"
      assert output =~ "<source_directory>"
    end

    test "handles version short flag" do
      output =
        capture_io(fn ->
          CLI.parse(["-v"])
        end)

      assert output =~ "0.1.0"
    end

    test "handles restore short flag" do
      output =
        capture_io(fn ->
          CLI.parse(["-r"])
        end)

      assert output =~ "No backup log found"
    end
  end

  describe "private functions" do
    setup do
      # Create a test source directory for private function testing
      test_source = "/tmp/dotfiler_private_test"
      File.rm_rf(test_source)
      File.mkdir_p!(test_source)
      File.write!("#{test_source}/testfile", "test content")

      on_exit(fn ->
        File.rm_rf(test_source)
      end)

      {:ok, test_source: test_source}
    end

    test "validate_source_directory! with valid directory", %{test_source: test_source} do
      # This should not raise an error
      capture_io(fn ->
        CLI.execute(source: test_source)
      end)
    end

    test "validate_source_directory! with non-existent directory" do
      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.execute(source: "/non/existent/directory")
        end)
      end
    end

    test "validate_source_directory! with file instead of directory" do
      file_path = "/tmp/test_file_not_dir"
      File.write!(file_path, "content")

      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.execute(source: file_path)
        end)
      end

      File.rm(file_path)
    end

    test "exit_with_error in test environment" do
      # This should raise RuntimeError in test environment
      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.execute(source: "/non/existent")
        end)
      end
    end

    test "handles mixed valid and invalid options" do
      # Test with a mix of valid options and invalid source
      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.execute(source: "/non/existent", dry_run: true, brew: true)
        end)
      end
    end

    test "validates that source is a directory not a file" do
      # Create a file instead of a directory
      test_file = "#{@tmp_dir}/not_a_directory.txt"
      File.write!(test_file, "content")

      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.execute(source: test_file)
        end)
      end

      File.rm!(test_file)
    end
  end

  describe "argument parsing edge cases" do
    test "handles unknown options gracefully" do
      # OptionParser should ignore unknown options
      output =
        capture_io(fn ->
          CLI.parse(["--unknown-option", "--help"])
        end)

      assert output =~ "Usage:"
    end

    test "handles empty arguments list" do
      output =
        capture_io(fn ->
          CLI.parse([])
        end)

      assert output =~ "Usage:"
      assert output =~ "--help"
    end

    test "handles no arguments (uses default)" do
      output =
        capture_io(fn ->
          # Call without arguments to test default parameter
          CLI.parse()
        end)

      assert output =~ "Usage:"
      assert output =~ "--help"
    end

    test "handles only aliases" do
      output =
        capture_io(fn ->
          CLI.parse(["-h"])
        end)

      assert output =~ "Usage:"
    end

    test "handles version with alias" do
      output =
        capture_io(fn ->
          CLI.parse(["-v"])
        end)

      assert output =~ "0.1.0"
    end

    test "handles restore with alias" do
      output =
        capture_io(fn ->
          CLI.parse(["-r"])
        end)

      # Should attempt to restore (will show "No backup log found" since no backups exist)
      assert output =~ "No backup log found"
    end

    test "help takes precedence when both positional arg and help provided" do
      # Create a valid source directory
      File.mkdir_p!(@tmp_dir)

      output =
        capture_io(fn ->
          CLI.parse([@tmp_dir, "--help"])
        end)

      # Help should take precedence
      assert output =~ "Usage:"
    end

    test "handles dry-run with alias" do
      File.mkdir_p!(@tmp_dir)
      File.write!("#{@tmp_dir}/testfile", "content")

      output =
        capture_io(fn ->
          CLI.parse([@tmp_dir, "-d"])
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "Would symlink"
    end

    test "handles brew with alias" do
      File.mkdir_p!(@tmp_dir)
      # Don't create Brewfile, so it should show warning about missing Brewfile

      output =
        capture_io(fn ->
          CLI.parse([@tmp_dir, "-b", "-d"])
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "No Brewfile found"
    end

    test "help takes precedence over positional argument when both provided" do
      output =
        capture_io(fn ->
          CLI.parse(["--help", @source_dir])
        end)

      # Help should take precedence based on the flag order
      assert output =~ "Usage:"
      assert output =~ "<source_directory>"
    end

    test "version takes precedence over positional argument when both provided" do
      output =
        capture_io(fn ->
          CLI.parse(["--version", @source_dir])
        end)

      # Version should take precedence
      assert output =~ "0.1.0"
    end

    test "restore takes precedence over positional argument when both provided" do
      output =
        capture_io(fn ->
          CLI.parse(["--restore", @source_dir])
        end)

      # Restore should take precedence
      assert output =~ "No backup log found"
    end
  end

  describe "execute function edge cases" do
    test "execute with all options enabled" do
      File.write!("#{@source_dir}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          CLI.execute(source: @source_dir, brew: true, dry_run: true)
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "Would install Homebrew packages" or output =~ "No Brewfile found"
    end

    test "execute with default options" do
      output =
        capture_io(fn ->
          CLI.execute(source: @source_dir)
        end)

      # Should process files without brew or dry-run
      assert output =~ "bashrc" or output =~ "File:"
    end

    test "execute validates source directory before processing" do
      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.execute(source: "/absolutely/nonexistent/path")
        end)
      end
    end
  end

  describe "positional argument support" do
    test "accepts source directory as positional argument" do
      output =
        capture_io(fn ->
          CLI.parse([@source_dir])
        end)

      # Should process the source directory
      assert output =~ "bashrc" or output =~ "File:"
    end

    test "positional argument with dry-run flag" do
      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--dry-run"])
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "[DRY RUN]"
    end

    test "positional argument with brew flag" do
      File.write!("#{@source_dir}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--brew"])
        end)

      # Should attempt to install Homebrew packages and link files
      assert output =~ "Installing Homebrew packages" or output =~ "No Brewfile found"
    end

    test "positional argument with multiple flags" do
      File.write!("#{@source_dir}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--brew", "--dry-run"])
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "[DRY RUN]"
      assert output =~ "Would install Homebrew packages"
    end

    test "validates positional source directory exists" do
      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.parse(["/non/existent/positional/path"])
        end)
      end
    end

    test "validates positional source is a directory" do
      file_path = "#{@tmp_dir}/not_a_dir_positional"
      File.write!(file_path, "content")

      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.parse([file_path])
        end)
      end
    end

    test "help flag takes precedence over positional argument" do
      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--help"])
        end)

      assert output =~ "Usage:"
      assert output =~ "<source_directory>"
    end

    test "version flag takes precedence over positional argument" do
      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--version"])
        end)

      assert output =~ "0.1.0"
    end

    test "restore flag takes precedence over positional argument" do
      output =
        capture_io(fn ->
          CLI.parse([@source_dir, "--restore"])
        end)

      assert output =~ "No backup log found"
    end
  end
end
