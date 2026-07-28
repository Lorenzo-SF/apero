defmodule Apero.File.Tree do
  @moduledoc """
  ASCII tree generation and printing for file listings.

  These functions are exposed via `Apero.File.*` delegates. You normally call them
  through `Apero.File` rather than directly.
  """

  @doc false
  @spec generate_tree([binary()]) :: binary()
  def generate_tree(paths) when is_list(paths) do
    paths
    |> Enum.sort()
    |> build_tree()
    |> render_tree("", true)
    |> String.trim_trailing()
  end

  defp build_tree(paths) do
    paths
    |> Enum.reduce(%{}, fn path, tree ->
      parts = Path.split(path)
      insert_path(tree, parts)
    end)
    |> sort_tree()
  end

  defp insert_path(tree, [part]), do: Map.put(tree, part, %{})

  defp insert_path(tree, [part | rest]),
    do: Map.update(tree, part, insert_path(%{}, rest), &insert_path(&1, rest))

  defp sort_tree(tree) do
    tree
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.map(fn {k, v} -> {k, sort_tree(v)} end)
  end

  defp render_tree([], _prefix, _is_last), do: ""

  defp render_tree([{name, children}], prefix, _is_last) do
    line = "#{prefix}└─ #{name}"
    child_prefix = prefix <> "   "
    children_str = render_tree(children, child_prefix, true)
    join_lines(line, children_str)
  end

  defp render_tree([{name, children} | rest], prefix, _is_last) do
    line = "#{prefix}├─ #{name}"
    child_prefix = prefix <> "│  "
    children_str = render_tree(children, child_prefix, false)
    rest_str = render_tree(rest, prefix, false)
    join_lines(line, join_lines(children_str, rest_str))
  end

  defp join_lines("", rest), do: rest
  defp join_lines(line, ""), do: line
  defp join_lines(line, rest), do: line <> "\n" <> rest

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
