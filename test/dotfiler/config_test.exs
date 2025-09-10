defmodule Dotfiler.ConfigTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Dotfiler.Config

  @tmp_dir "/tmp/dotfiler_config_test"
  @test_config_content """
  [general]
  backup_dir = "~/custom_backup"
  dry_run = true
  verbose = true

  [filtering]
  exclude = ["*.tmp", "*.log", ".*"]

  [linking]
  backup_existing = false
  on_conflict = "skip"

  [packages]
  auto_brew = true
  brewfile_name = "CustomBrewfile"
  """

  setup do
    File.rm_rf(@tmp_dir)
    File.mkdir_p!(@tmp_dir)

    # Save original working directory
    original_cwd = File.cwd!()

    on_exit(fn ->
      File.rm_rf(@tmp_dir)
      File.cd!(original_cwd)
    end)

    {:ok, tmp_dir: @tmp_dir, original_cwd: original_cwd}
  end

  describe "load/1" do
    test "loads default configuration when no config file exists" do
      config = Config.load()

      assert config.general.backup_dir == "~/.dotfiler_backup"
      assert config.general.dry_run == false
      assert config.filtering.exclude == [".*", "[A-Z]*"]
      assert config.packages.auto_brew == false
    end

    test "loads configuration from custom path", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "custom.toml")
      File.write!(config_path, @test_config_content)

      config = Config.load(config_path)

      assert config.general.backup_dir == "~/custom_backup"
      assert config.general.dry_run == true
      assert config.filtering.exclude == ["*.tmp", "*.log", ".*"]
      assert config.packages.auto_brew == true
      assert config.packages.brewfile_name == "CustomBrewfile"
    end

    test "loads configuration from .dotfilerrc in current directory", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir)
      config_file = Path.join(tmp_dir, ".dotfilerrc")
      File.write!(config_file, @test_config_content)

      config = Config.load()

      assert config.general.backup_dir == "~/custom_backup"
      assert config.packages.auto_brew == true
    end

    test "loads configuration from ~/.dotfilerrc", %{tmp_dir: _tmp_dir} do
      home_config = Path.expand("~/.dotfilerrc")

      # Clean up any existing config
      File.rm(home_config)

      File.write!(home_config, @test_config_content)

      on_exit(fn -> File.rm(home_config) end)

      config = Config.load()

      assert config.general.backup_dir == "~/custom_backup"
      assert config.packages.auto_brew == true
    end

    test "prioritizes project config over user config", %{tmp_dir: tmp_dir} do
      File.cd!(tmp_dir)

      # Create user config
      home_config = Path.expand("~/.dotfilerrc")

      File.write!(home_config, """
      [general]
      backup_dir = "~/user_backup"
      """)

      # Create project config
      project_config = Path.join(tmp_dir, ".dotfilerrc")

      File.write!(project_config, """
      [general]
      backup_dir = "~/project_backup"
      """)

      on_exit(fn -> File.rm(home_config) end)

      config = Config.load()

      # Project config should take precedence
      assert config.general.backup_dir == "~/project_backup"
    end

    test "handles invalid TOML gracefully", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "invalid.toml")
      File.write!(config_path, "invalid toml content [")

      output =
        capture_io(fn ->
          config = Config.load(config_path)

          # Should fallback to defaults
          assert config.general.backup_dir == "~/.dotfiler_backup"
          assert config.general.dry_run == false
        end)

      assert output =~ "Invalid TOML"
    end

    test "handles missing config file gracefully", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "nonexistent.toml")

      output =
        capture_io(fn ->
          config = Config.load(config_path)

          # Should fallback to defaults
          assert config.general.backup_dir == "~/.dotfiler_backup"
        end)

      assert output =~ "Could not read config file"
    end

    test "handles unknown configuration sections gracefully", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "unknown.toml")

      File.write!(config_path, """
      [unknown_section]
      some_key = "value"

      [general]
      backup_dir = "~/test"
      """)

      output =
        capture_io(fn ->
          config = Config.load(config_path)

          # Should still load valid sections
          assert config.general.backup_dir == "~/test"
        end)

      assert output =~ "Unknown configuration section"
    end

    test "handles unknown configuration keys gracefully", %{tmp_dir: tmp_dir} do
      config_path = Path.join(tmp_dir, "unknown_key.toml")

      File.write!(config_path, """
      [general]
      backup_dir = "~/test"
      unknown_key = "value"
      """)

      output =
        capture_io(fn ->
          config = Config.load(config_path)

          # Should still load valid keys
          assert config.general.backup_dir == "~/test"
        end)

      assert output =~ "Unknown configuration key"
    end
  end

  describe "get/3" do
    test "retrieves nested configuration values" do
      config = %{
        general: %{backup_dir: "~/test"},
        filtering: %{exclude: [".*"]}
      }

      assert Config.get(config, [:general, :backup_dir]) == "~/test"
      assert Config.get(config, [:filtering, :exclude]) == [".*"]
      assert Config.get(config, [:nonexistent, :key]) == nil
      assert Config.get(config, [:nonexistent, :key], "default") == "default"
    end
  end

  describe "merge_with_cli_options/2" do
    test "merges CLI options with configuration" do
      config = %{
        general: %{dry_run: false},
        packages: %{auto_brew: false}
      }

      cli_options = [dry_run: true, brew: true]
      merged = Config.merge_with_cli_options(config, cli_options)

      assert merged.general.dry_run == true
      assert merged.packages.auto_brew == true
    end

    test "CLI options override config values" do
      config = %{
        general: %{dry_run: true},
        packages: %{auto_brew: true}
      }

      cli_options = [dry_run: false, brew: false]
      merged = Config.merge_with_cli_options(config, cli_options)

      assert merged.general.dry_run == false
      assert merged.packages.auto_brew == false
    end

    test "ignores nil CLI options" do
      config = %{
        general: %{dry_run: true},
        packages: %{auto_brew: true}
      }

      cli_options = [dry_run: nil, brew: nil]
      merged = Config.merge_with_cli_options(config, cli_options)

      # Config values should remain unchanged
      assert merged.general.dry_run == true
      assert merged.packages.auto_brew == true
    end
  end

  describe "configuration file discovery" do
    test "finds configuration in XDG config directory", %{tmp_dir: tmp_dir} do
      # Mock the home directory for this test
      xdg_config_dir = Path.join(tmp_dir, ".config/dotfiler")
      File.mkdir_p!(xdg_config_dir)

      config_file = Path.join(xdg_config_dir, "config.toml")
      File.write!(config_file, @test_config_content)

      # Mock Path.expand to return our test directory
      :meck.new(Path, [:passthrough])

      :meck.expect(Path, :expand, fn
        "~/.config/dotfiler/config.toml" -> config_file
        path -> :meck.passthrough([path])
      end)

      try do
        config = Config.load()
        assert config.general.backup_dir == "~/custom_backup"
      after
        :meck.unload(Path)
      end
    end
  end
end
