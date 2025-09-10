defmodule Dotfiler.ExitHandler do
  @moduledoc """
  Handles process exit behavior for the application.

  In test environment, raises exceptions instead of halting the system,
  allowing tests to catch and verify error conditions.
  """

  # Capture test environment at compile time
  @test_env if Code.ensure_loaded?(Mix), do: Mix.env() == :test, else: false

  @doc """
  Exits the application with an error.

  In test environment, raises an exception with the provided message.
  In production, halts the system with exit code 1.

  ## Parameters
    - `message` - Error message (used in test environment)

  ## Examples
      iex> Dotfiler.ExitHandler.exit_with_error("Operation failed")
      # In tests: raises RuntimeError
      # In production: calls System.halt(1)
  """
  @spec exit_with_error(String.t()) :: no_return()
  def exit_with_error(message) do
    if @test_env do
      raise message
    else
      System.halt(1)
    end
  end
end
