defmodule DotfilerTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias Dotfiler

  describe "main/1" do
    test "calls CLI.parse with provided arguments" do
      output =
        capture_io(fn ->
          Dotfiler.main(["--help"])
        end)

      assert output =~ "Usage:"
      assert output =~ "--source"
    end

    test "calls CLI.parse with empty arguments" do
      output =
        capture_io(fn ->
          Dotfiler.main([])
        end)

      assert output =~ "Usage:"
      assert output =~ "--help"
    end

    test "calls CLI.parse with version flag" do
      output =
        capture_io(fn ->
          Dotfiler.main(["--version"])
        end)

      assert output =~ "0.1.0"
    end

    test "defaults to empty arguments when none provided" do
      output =
        capture_io(fn ->
          Dotfiler.main()
        end)

      assert output =~ "Usage:"
      assert output =~ "--source"
    end
  end
end
