defmodule Dotfiler.LinkTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Dotfiler.Link

  @tmp_dir "/tmp/dotfiler_test"
  @source_dir "#{@tmp_dir}/source"
  @home_dir "#{@tmp_dir}/home"
  @backup_dir "#{@home_dir}/.dotfiler_backup"

  setup do
    # Clean up any existing test directories
    File.rm_rf(@tmp_dir)

    # Create test directories
    File.mkdir_p!(@source_dir)
    File.mkdir_p!(@home_dir)

    # Mock System.user_home to return our test home directory
    original_user_home = System.get_env("HOME")
    System.put_env("HOME", @home_dir)

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

  describe "from_source/2" do
    test "handles non-existent source directory" do
      assert_raise RuntimeError, "Link operation failed", fn ->
        capture_io(fn ->
          Link.from_source("/non/existent/path")
        end)
      end
    end

    test "filters out dotfiles and uppercase files" do
      # Create test files
      File.write!("#{@source_dir}/bashrc", "# bashrc content")
      File.write!("#{@source_dir}/.hidden", "# hidden content")
      File.write!("#{@source_dir}/README", "# readme content")
      File.write!("#{@source_dir}/vimrc", "# vimrc content")

      capture_io(fn ->
        Link.from_source(@source_dir)
      end)

      # Should create symlinks for bashrc and vimrc only
      assert File.exists?("#{@home_dir}/.bashrc")
      assert File.exists?("#{@home_dir}/.vimrc")
      refute File.exists?("#{@home_dir}/.hidden")
      refute File.exists?("#{@home_dir}/.README")
    end

    test "creates backups of existing files" do
      # Create source file
      File.write!("#{@source_dir}/bashrc", "# new bashrc")

      # Create existing file in home
      existing_content = "# existing bashrc"
      File.write!("#{@home_dir}/.bashrc", existing_content)

      capture_io(fn ->
        Link.from_source(@source_dir)
      end)

      # Check that backup was created
      assert File.exists?("#{@backup_dir}/bashrc")
      assert File.read!("#{@backup_dir}/bashrc") == existing_content

      # Check that symlink was created
      assert File.lstat!("#{@home_dir}/.bashrc").type == :symlink
    end

    test "dry run mode doesn't make changes" do
      File.write!("#{@source_dir}/bashrc", "# bashrc content")
      File.write!("#{@home_dir}/.bashrc", "# existing content")

      capture_io(fn ->
        Link.from_source(@source_dir, dry_run: true)
      end)

      # Original file should be unchanged
      assert File.read!("#{@home_dir}/.bashrc") == "# existing content"
      refute File.exists?("#{@backup_dir}/bashrc")
    end
  end

  describe "restore_backups/0" do
    test "restores backed up files" do
      # Create a backup scenario
      File.mkdir_p!(@backup_dir)
      File.write!("#{@backup_dir}/bashrc", "# original content")

      # Create backup log
      log_entry = "2025-01-01T00:00:00Z | bashrc | #{@home_dir}/.bashrc | #{@backup_dir}/bashrc\n"
      File.write!("#{@backup_dir}/backup.log", log_entry)

      # Create symlink that should be removed
      File.write!("#{@source_dir}/bashrc", "# source content")
      File.ln_s!("#{@source_dir}/bashrc", "#{@home_dir}/.bashrc")

      capture_io(fn ->
        Link.restore_backups()
      end)

      # Check that original file was restored
      assert File.read!("#{@home_dir}/.bashrc") == "# original content"
      refute File.exists?("#{@backup_dir}/bashrc")
    end

    test "handles missing backup log gracefully" do
      output =
        capture_io(fn ->
          Link.restore_backups()
        end)

      assert output =~ "No backup log found"
    end
  end
end
