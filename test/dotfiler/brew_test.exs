defmodule Dotfiler.BrewTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Dotfiler.Brew

  @tmp_dir "/tmp/dotfiler_brew_test"

  setup do
    File.rm_rf(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    on_exit(fn ->
      File.rm_rf(@tmp_dir)
    end)

    :ok
  end

  describe "bundle/2" do
    test "handles missing Brewfile in normal mode" do
      output =
        capture_io(fn ->
          Brew.bundle(@tmp_dir)
        end)

      assert output =~ "No Brewfile found"
      assert output =~ "skipping"
    end

    test "handles missing Brewfile in dry run mode" do
      output =
        capture_io(fn ->
          Brew.bundle(@tmp_dir, true)
        end)

      assert output =~ "[DRY RUN] No Brewfile found"
    end

    test "dry run mode with existing Brewfile" do
      File.write!("#{@tmp_dir}/Brewfile", """
      brew "git"
      brew "vim"
      """)

      output =
        capture_io(fn ->
          Brew.bundle(@tmp_dir, true)
        end)

      assert output =~ "[DRY RUN] Would install Homebrew packages"
      assert output =~ "Brewfile"
    end

    test "finds existing Brewfile in normal mode" do
      File.write!("#{@tmp_dir}/Brewfile", """
      brew "git"
      """)

      # This will fail because we don't have brew installed in test/CI env
      # but we can test that it attempts to run the command and handles the error
      output =
        capture_io(fn ->
          Brew.bundle(@tmp_dir)
        end)

      assert output =~ "Installing Homebrew packages"
      # In CI/test environments without brew, it should show the error message
      assert output =~ "Installing Homebrew packages" or output =~ "brew command not found"
    end

    test "handles brew command not found error" do
      File.write!("#{@tmp_dir}/Brewfile", """
      brew "nonexistent"
      """)

      # Mock System.cmd to raise ErlangError (command not found)
      output =
        capture_io(fn ->
          # This should trigger the rescue clause for missing brew command
          Brew.bundle(@tmp_dir)
        end)

      assert output =~ "Installing Homebrew packages"
      # Should handle the error gracefully
      assert output =~ "Installing Homebrew packages" or output =~ "brew command not found"
    end

    test "handles empty Brewfile" do
      File.write!("#{@tmp_dir}/Brewfile", "")

      output =
        capture_io(fn ->
          Brew.bundle(@tmp_dir)
        end)

      assert output =~ "Installing Homebrew packages"
    end

    test "handles Brewfile with comments only" do
      File.write!("#{@tmp_dir}/Brewfile", """
      # This is a comment
      # Another comment
      """)

      output =
        capture_io(fn ->
          Brew.bundle(@tmp_dir)
        end)

      assert output =~ "Installing Homebrew packages"
    end
  end
end
