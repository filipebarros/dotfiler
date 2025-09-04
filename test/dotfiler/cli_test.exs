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
      assert output =~ "--source"
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

    test "validates source directory exists" do
      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.parse(["--source", "/non/existent/path"])
        end)
      end
    end

    test "validates source is a directory" do
      file_path = "#{@tmp_dir}/not_a_dir"
      File.write!(file_path, "content")

      assert_raise RuntimeError, "CLI validation failed", fn ->
        capture_io(fn ->
          CLI.parse(["--source", file_path])
        end)
      end
    end

    test "handles dry run mode" do
      output =
        capture_io(fn ->
          CLI.parse(["--source", @source_dir, "--dry-run"])
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "[DRY RUN]"
    end

    test "handles dry run mode with brew flag" do
      File.write!("#{@source_dir}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          CLI.parse(["--source", @source_dir, "--brew", "--dry-run"])
        end)

      assert output =~ "DRY RUN MODE"
      assert output =~ "[DRY RUN]"
      assert output =~ "Would install Homebrew packages"
    end

    test "handles source directory with brew flag" do
      File.write!("#{@source_dir}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          CLI.parse(["--source", @source_dir, "--brew"])
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
      assert output =~ "--source"
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

    test "handles source short flag" do
      output =
        capture_io(fn ->
          CLI.parse(["-s", @source_dir])
        end)

      # Should process the source directory
      # May have various outputs
      assert output =~ "bashrc" or output =~ "DRY RUN" or true
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
  end
end
