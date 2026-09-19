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

      :meck.new(System, [:passthrough])

      :meck.expect(System, :cmd, fn "brew", ["bundle"], [cd: @tmp_dir] ->
        {"", 0}
      end)

      try do
        output =
          capture_io(fn ->
            Brew.bundle(@tmp_dir)
          end)

        assert output =~ "Successfully installed Homebrew packages"
      after
        :meck.unload(System)
      end
    end

    test "handles empty Brewfile" do
      File.write!("#{@tmp_dir}/Brewfile", "")

      :meck.new(System, [:passthrough])

      :meck.expect(System, :cmd, fn "brew", ["bundle"], [cd: @tmp_dir] ->
        {"", 0}
      end)

      try do
        output =
          capture_io(fn ->
            Brew.bundle(@tmp_dir)
          end)

        assert output =~ "Successfully installed Homebrew packages"
      after
        :meck.unload(System)
      end
    end

    test "handles Brewfile with comments only" do
      File.write!("#{@tmp_dir}/Brewfile", """
      # This is a comment
      # Another comment
      """)

      :meck.new(System, [:passthrough])

      :meck.expect(System, :cmd, fn "brew", ["bundle"], [cd: @tmp_dir] ->
        {"", 0}
      end)

      try do
        output =
          capture_io(fn ->
            Brew.bundle(@tmp_dir)
          end)

        assert output =~ "Successfully installed Homebrew packages"
      after
        :meck.unload(System)
      end
    end
  end

  describe "error handling" do
    test "handles brew command not found" do
      File.write!("#{@tmp_dir}/Brewfile", "brew 'git'")

      # Mock System.cmd to raise ErlangError (command not found)
      :meck.new(System, [:passthrough])

      :meck.expect(System, :cmd, fn "brew", ["bundle"], [cd: @tmp_dir] ->
        raise ErlangError, reason: :enoent
      end)

      try do
        output =
          capture_io(fn ->
            Brew.bundle(@tmp_dir)
          end)

        assert output =~ "Homebrew (brew) command not found"
        assert output =~ "Please install Homebrew first"
      after
        :meck.unload(System)
      end
    end

    test "handles brew bundle failure with output" do
      File.write!("#{@tmp_dir}/Brewfile", "brew 'nonexistent-package-xyz'")

      # Mock System.cmd to return failure with error output
      :meck.new(System, [:passthrough])

      :meck.expect(System, :cmd, fn "brew", ["bundle"], [cd: @tmp_dir] ->
        {"Error: Formula 'nonexistent-package-xyz' not found", 1}
      end)

      try do
        output =
          capture_io(fn ->
            Brew.bundle(@tmp_dir)
          end)

        assert output =~ "Failed to install Homebrew packages (exit code: 1)"
        assert output =~ "Error output: Error: Formula 'nonexistent-package-xyz' not found"
      after
        :meck.unload(System)
      end
    end

    test "handles brew bundle failure without output" do
      File.write!("#{@tmp_dir}/Brewfile", "brew 'git'")

      # Mock System.cmd to return failure with empty output
      :meck.new(System, [:passthrough])

      :meck.expect(System, :cmd, fn "brew", ["bundle"], [cd: @tmp_dir] ->
        {"", 1}
      end)

      try do
        output =
          capture_io(fn ->
            Brew.bundle(@tmp_dir)
          end)

        assert output =~ "Failed to install Homebrew packages (exit code: 1)"
        # Should not show error output section when output is empty
        refute output =~ "Error output:"
      after
        :meck.unload(System)
      end
    end

    test "handles brew bundle failure with whitespace-only output" do
      File.write!("#{@tmp_dir}/Brewfile", "brew 'git'")

      # Mock System.cmd to return failure with whitespace-only output
      :meck.new(System, [:passthrough])

      :meck.expect(System, :cmd, fn "brew", ["bundle"], [cd: @tmp_dir] ->
        {"   \n\t  ", 1}
      end)

      try do
        output =
          capture_io(fn ->
            Brew.bundle(@tmp_dir)
          end)

        assert output =~ "Failed to install Homebrew packages (exit code: 1)"
        # Should not show error output section when output is only whitespace
        refute output =~ "Error output:"
      after
        :meck.unload(System)
      end
    end
  end

  describe "edge cases" do
    test "handles corrupted Brewfile" do
      # Create a Brewfile with invalid syntax
      File.write!("#{@tmp_dir}/Brewfile", """
      This is not valid Brewfile syntax
      Random text that will cause brew bundle to fail
      """)

      :meck.new(System, [:passthrough])

      :meck.expect(System, :cmd, fn "brew", ["bundle"], [cd: @tmp_dir] ->
        {"Error: Invalid Brewfile syntax", 1}
      end)

      try do
        output =
          capture_io(fn ->
            Brew.bundle(@tmp_dir)
          end)

        assert output =~ "Failed to install Homebrew packages (exit code: 1)"
        assert output =~ "Error output: Error: Invalid Brewfile syntax"
      after
        :meck.unload(System)
      end
    end

    test "handles Brewfile with only whitespace" do
      File.write!("#{@tmp_dir}/Brewfile", """



      """)

      output =
        capture_io(fn ->
          Brew.bundle(@tmp_dir)
        end)

      assert output =~ "Installing Homebrew packages"
    end

    test "handles very long source path" do
      # Create a deeply nested directory structure
      long_path =
        Path.join([
          @tmp_dir,
          "very",
          "deeply",
          "nested",
          "directory",
          "structure",
          "for",
          "testing"
        ])

      File.mkdir_p!(long_path)
      File.write!("#{long_path}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          # Use dry run to avoid actual brew execution
          Brew.bundle(long_path, true)
        end)

      assert output =~ "[DRY RUN] Would install Homebrew packages"
      assert output =~ long_path
    end

    test "handles source path with special characters" do
      special_dir = "#{@tmp_dir}/test-dir with spaces & symbols!"
      File.mkdir_p!(special_dir)
      File.write!("#{special_dir}/Brewfile", "brew 'git'")

      output =
        capture_io(fn ->
          # Use dry run
          Brew.bundle(special_dir, true)
        end)

      assert output =~ "[DRY RUN] Would install Homebrew packages"
      assert output =~ special_dir
    end
  end
end
