defmodule Mix.Tasks.Landing.RecordBuildInfo do
  @shortdoc "Writes priv/build_info.json with git metadata at build time"

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    info = %{
      commit_sha: cmd(["git", "log", "-1", "--format=%H"]),
      commit_short_sha: cmd(["git", "log", "-1", "--format=%h"]),
      commit_subject: cmd(["git", "log", "-1", "--format=%s"]),
      commit_timestamp: to_integer(cmd(["git", "log", "-1", "--format=%ct"])),
      phase_tags: phase_tags(),
      built_at: System.os_time(:second)
    }

    path = Path.join(:code.priv_dir(:intellispark), "build_info.json")
    File.write!(path, Jason.encode!(info, pretty: true))
    Mix.shell().info("[landing] wrote #{path}")
  end

  defp phase_tags do
    case cmd_safe([
           "git",
           "tag",
           "--list",
           "--format=%(refname:short)|%(objectname:short)|%(creatordate:unix)|%(subject)"
         ]) do
      "" ->
        []

      out ->
        out
        |> String.split("\n", trim: true)
        |> Enum.map(&parse_tag_line/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.timestamp)
    end
  end

  defp parse_tag_line(line) do
    case String.split(line, "|", parts: 4) do
      [tag, sha, ts, subject] ->
        %{tag: tag, commit_sha: sha, timestamp: to_integer(ts), subject: subject}

      [tag, sha, ts] ->
        %{tag: tag, commit_sha: sha, timestamp: to_integer(ts), subject: ""}

      _ ->
        nil
    end
  end

  defp to_integer(""), do: 0
  defp to_integer(s), do: String.to_integer(s)

  defp cmd(args) do
    {out, 0} = System.cmd(hd(args), tl(args), stderr_to_stdout: true)
    String.trim(out)
  end

  defp cmd_safe(args) do
    case System.cmd(hd(args), tl(args), stderr_to_stdout: true) do
      {out, 0} -> String.trim(out)
      _ -> ""
    end
  end
end
