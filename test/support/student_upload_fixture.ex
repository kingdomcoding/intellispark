defmodule Intellispark.StudentUploadFixture do
  @moduledoc """
  Helpers for Phase 3 photo-upload tests. Writes a tiny real PNG to a
  temp path so the Students.upload_student_photo action has a valid
  binary to copy, plus builders for oversized / wrong-MIME payloads.
  """

  # Smallest valid PNG: 1x1 transparent pixel. Generated via:
  #   iex> Base.encode64(<<137, 80, 78, 71, ... >>)
  @png_1x1 Base.decode64!(
             "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg=="
           )

  def png_photo(filename \\ "tiny.png") do
    path = write_temp(filename, @png_1x1)
    %{path: path, content_type: "image/png", filename: filename}
  end

  def oversized_png(filename \\ "big.png") do
    padding = :binary.copy(<<0>>, 6 * 1024 * 1024)
    path = write_temp(filename, @png_1x1 <> padding)
    %{path: path, content_type: "image/png", filename: filename}
  end

  def pdf_photo(filename \\ "fake.pdf") do
    path = write_temp(filename, "%PDF-1.4\n%fake\n")
    %{path: path, content_type: "application/pdf", filename: filename}
  end

  defp write_temp(filename, bytes) do
    dir = Path.join(System.tmp_dir!(), "intellispark-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    path = Path.join(dir, filename)
    File.write!(path, bytes)
    path
  end
end
