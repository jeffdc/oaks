defmodule OaksWeb.PrivateAPI.ImportJSON do
  @moduledoc """
  The import endpoint's responses (`OaksWeb.PrivateAPI.ImportController`).
  """

  alias Oaks.Import
  alias Oaks.Import.AppliedImport

  @doc "A dry run's report, with the token its apply must carry."
  @spec dry_run(Import.report(), binary(), String.t(), DateTime.t()) :: map()
  def dry_run(report, body_sha256, token, expires_at) do
    %{
      status: "dry_run",
      body_sha256: hex(body_sha256),
      dry_run_token: token,
      token_expires_at: expires_at,
      summary: report.summary,
      records: report.records
    }
  end

  @doc "An applied import's report, with the ids of the rows it created."
  @spec applied(Import.report(), binary()) :: map()
  def applied(report, body_sha256) do
    %{
      status: "applied",
      body_sha256: hex(body_sha256),
      summary: report.summary,
      records: report.records
    }
  end

  @doc "An import that was applied before; nothing was done this time."
  @spec already_applied(AppliedImport.t()) :: map()
  def already_applied(%AppliedImport{} = applied) do
    %{
      status: "already_applied",
      applied_at: applied.inserted_at,
      import_id: applied.import_id,
      body_sha256: hex(applied.body_sha256)
    }
  end

  @doc "Every error found; nothing was written."
  @spec errors([Import.error()]) :: map()
  def errors(errors), do: %{errors: errors}

  defp hex(sha256), do: Base.encode16(sha256, case: :lower)
end
