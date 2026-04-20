defmodule Intellispark.Students.Changes.UploadStudentPhoto do
  @moduledoc """
  Called by Student.upload_photo/3. Expects a `:photo` argument shaped
  `%{path: tmp_path, content_type: mime, filename: name}`. Validates the
  MIME type + size, copies the file into
  `priv/static/uploads/students/<student_id>/<uuid>.<ext>`, and sets
  `photo_url` to the publicly-served path.

  Validation runs in change/3 so AshAdmin form submissions get the same
  error shape as LiveView uploads.
  """

  use Ash.Resource.Change

  @max_bytes 5 * 1024 * 1024
  @allowed_mime ~w(image/png image/jpeg image/webp)
  @ext_of %{"image/png" => "png", "image/jpeg" => "jpg", "image/webp" => "webp"}

  @impl true
  def change(changeset, _opts, _context) do
    photo = Ash.Changeset.get_argument(changeset, :photo)

    with :ok <- validate_presence(photo),
         :ok <- validate_mime(photo[:content_type] || photo["content_type"]),
         :ok <- validate_size(photo[:path] || photo["path"]) do
      Ash.Changeset.before_action(changeset, &copy_to_uploads(&1, photo))
    else
      {:error, message} ->
        Ash.Changeset.add_error(changeset, field: :photo, message: message)
    end
  end

  defp validate_presence(nil), do: {:error, "photo is required"}
  defp validate_presence(photo) when is_map(photo), do: :ok
  defp validate_presence(_), do: {:error, "photo must be a map"}

  defp validate_mime(ct) when ct in @allowed_mime, do: :ok
  defp validate_mime(_), do: {:error, "unsupported image type (PNG / JPEG / WEBP only)"}

  defp validate_size(path) when is_binary(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= @max_bytes -> :ok
      {:ok, _} -> {:error, "image must be 5MB or smaller"}
      _ -> {:error, "could not read uploaded file"}
    end
  end

  defp validate_size(_), do: {:error, "missing uploaded file path"}

  defp copy_to_uploads(changeset, photo) do
    student_id =
      Ash.Changeset.get_attribute(changeset, :id) ||
        Map.get(changeset.data, :id)

    content_type = photo[:content_type] || photo["content_type"]
    source_path = photo[:path] || photo["path"]
    ext = Map.fetch!(@ext_of, content_type)

    basename = "#{Ash.UUID.generate()}.#{ext}"
    dir = upload_dir(student_id)
    File.mkdir_p!(dir)
    dest = Path.join(dir, basename)
    File.cp!(source_path, dest)

    Ash.Changeset.force_change_attribute(
      changeset,
      :photo_url,
      "/uploads/students/#{student_id}/#{basename}"
    )
  end

  defp upload_dir(student_id) do
    Path.join([
      :code.priv_dir(:intellispark),
      "static",
      "uploads",
      "students",
      student_id
    ])
  end
end
