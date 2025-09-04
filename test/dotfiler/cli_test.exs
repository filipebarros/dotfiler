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

    on_exit(fn ->
      File.rm_rf(@tmp_dir)
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
      assert_raise SystemExit, fn ->
        capture_io(fn ->
          CLI.parse(["--source", "/non/existent/path"])
        end)
      end
    end

    test "validates source is a directory" do
      file_path = "#{@tmp_dir}/not_a_dir"
      File.write!(file_path, "content")

      assert_raise SystemExit, fn ->
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
  end
end
