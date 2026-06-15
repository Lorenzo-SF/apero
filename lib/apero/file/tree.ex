defmodule Apero.File.Tree do
  @moduledoc false

  @doc false
  @spec generate_tree([binary()]) :: binary()
  def generate_tree(paths) when is_list(paths) do
    sorted = Enum.sort(paths)
    last_idx = length(sorted) - 1

    sorted
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {path, idx} ->
      parts = Path.split(path)
      indent = String.duplicate("  ", max(length(parts) - 1, 0))
      connector = if idx == last_idx, do: "└─", else: "├─"
      "#{indent}#{connector} #{Path.basename(path)}"
    end)
  end

  @doc false
  @spec print_tree(binary()) :: :ok
  def print_tree(path) do
    IO.puts("#{path}/")
    do_print_tree(path, "", true)
  end

  defp do_print_tree(path, prefix, _last) do
    case File.ls(path) do
      {:ok, entries} ->
        entries = Enum.sort(entries)
        print_entries(entries, prefix, path, length(entries))

      _ ->
        :ok
    end
  end

  defp print_entries(entries, prefix, path, total) do
    Enum.each(Enum.with_index(entries, 1), fn {entry, idx} ->
      is_last = idx == total
      connector = if is_last, do: "└── ", else: "├── "
      next_prefix = if is_last, do: prefix <> "    ", else: prefix <> "│   "
      IO.puts("#{prefix}#{connector}#{entry}")
      full = Path.join(path, entry)

      if File.dir?(full), do: do_print_tree(full, next_prefix, is_last)
    end)
  end
end
