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

      # This will fail because we don't have brew installed in test env
      # but we can test that it attempts to run the command
      output =
        capture_io(fn ->
          Brew.bundle(@tmp_dir)
        end)

      assert output =~ "Installing Homebrew packages"
    end
  end
end
