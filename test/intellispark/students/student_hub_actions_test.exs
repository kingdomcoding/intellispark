defmodule Intellispark.Students.StudentHubActionsTest do
  use Intellispark.DataCase, async: false

  import Intellispark.StudentsFixtures
  import Intellispark.StudentUploadFixture

  require Ash.Query

  alias Intellispark.Students
  alias Intellispark.Students.{StudentStatus, StudentTag}

  setup do: setup_world()

  describe "clear_status" do
    test "nils current_status_id and closes the active StudentStatus", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Clear", last_name: "Me"})
      status = create_status!(school, %{name: "Watch-Clear"})

      {:ok, student} =
        Students.set_student_status(student, status.id,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert student.current_status_id == status.id

      {:ok, cleared} =
        Students.clear_student_status(student,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert is_nil(cleared.current_status_id)

      {:ok, [row]} =
        StudentStatus
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)
        |> then(fn {:ok, rows} -> {:ok, rows} end)

      assert row.cleared_at
    end
  end

  describe "remove_tag" do
    test "destroys only the matching StudentTag, leaves others intact", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "Keep", last_name: "Others"})
      tag_keep = create_tag!(school, %{name: "Keep"})
      tag_remove = create_tag!(school, %{name: "Remove"})

      apply_tag!(admin, school, student, tag_keep)
      apply_tag!(admin, school, student, tag_remove)

      {:ok, _student} =
        Students.remove_tag_from_student(student, tag_remove.id,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      {:ok, rows} =
        StudentTag
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      assert Enum.map(rows, & &1.tag_id) == [tag_keep.id]
    end

    test "removing a tag that isn't applied is a silent no-op", %{
      school: school,
      admin: admin
    } do
      student = create_student!(school, %{first_name: "No", last_name: "Op"})
      tag = create_tag!(school, %{name: "NotApplied"})

      assert {:ok, _student} =
               Students.remove_tag_from_student(student, tag.id,
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )
    end
  end

  describe "upload_photo" do
    test "valid PNG copies the file and sets photo_url", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Photo", last_name: "Upload"})
      photo = png_photo("ava.png")

      {:ok, updated} =
        Students.upload_student_photo(student, photo,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      assert String.starts_with?(updated.photo_url, "/uploads/students/#{student.id}/")
      assert String.ends_with?(updated.photo_url, ".png")

      on_disk_path =
        Path.join([
          :code.priv_dir(:intellispark),
          "static",
          String.trim_leading(updated.photo_url, "/")
        ])

      assert File.exists?(on_disk_path)

      File.rm!(on_disk_path)
    end

    test "rejects non-image MIME type", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "PDF", last_name: "Reject"})
      photo = pdf_photo()

      assert {:error, %Ash.Error.Invalid{} = err} =
               Students.upload_student_photo(student, photo,
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )

      assert Enum.any?(err.errors, fn e ->
               Map.get(e, :field) == :photo and
                 String.contains?(to_string(Map.get(e, :message, "")), "unsupported")
             end)
    end

    test "rejects oversized files", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Big", last_name: "File"})
      photo = oversized_png()

      assert {:error, %Ash.Error.Invalid{} = err} =
               Students.upload_student_photo(student, photo,
                 actor: admin,
                 tenant: school.id,
                 authorize?: false
               )

      assert Enum.any?(err.errors, fn e ->
               Map.get(e, :field) == :photo and
                 String.contains?(to_string(Map.get(e, :message, "")), "5MB")
             end)
    end
  end

  describe "age_in_years calculation" do
    test "returns nil when date_of_birth is nil", %{school: school} do
      student = create_student!(school, %{first_name: "No", last_name: "DOB"})

      {:ok, loaded} =
        Ash.load(student, [:age_in_years], tenant: school.id, authorize?: false)

      assert is_nil(loaded.age_in_years)
    end

    test "returns an integer age when date_of_birth is set", %{school: school} do
      dob = Date.add(Date.utc_today(), -365 * 10 - 3)

      student =
        create_student!(school, %{first_name: "Known", last_name: "DOB", date_of_birth: dob})

      {:ok, loaded} =
        Ash.load(student, [:age_in_years], tenant: school.id, authorize?: false)

      assert loaded.age_in_years in 9..10
    end
  end

  describe "paper-trail student_id propagation" do
    test "StudentTag.Version rows carry student_id", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Trail", last_name: "Tag"})
      tag = create_tag!(school, %{name: "TrailTag"})
      apply_tag!(admin, school, student, tag)

      {:ok, [version]} =
        StudentTag.Version
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)
        |> then(fn {:ok, rows} -> {:ok, rows} end)

      assert version.student_id == student.id
    end

    test "StudentStatus.Version rows carry student_id", %{school: school, admin: admin} do
      student = create_student!(school, %{first_name: "Trail", last_name: "Status"})
      status = create_status!(school, %{name: "TrailStatus"})

      {:ok, _} =
        Students.set_student_status(student, status.id,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      {:ok, versions} =
        StudentStatus.Version
        |> Ash.Query.filter(student_id == ^student.id)
        |> Ash.Query.set_tenant(school.id)
        |> Ash.read(authorize?: false)

      assert Enum.all?(versions, &(&1.student_id == student.id))
      assert versions != []
    end
  end
end
