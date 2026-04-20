defmodule Intellispark.Students do
  @moduledoc """
  Domain for student records, per-school tagging + status, and saved
  CustomList filters. Every resource here is tenant-scoped by school_id.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Students.Student do
      define :list_students, action: :read
      define :get_student, action: :read, get_by: [:id]

      define :create_student,
        action: :create,
        args: [:first_name, :last_name, :grade_level]

      define :update_student, action: :update
      define :archive_student, action: :destroy
    end

    resource Intellispark.Students.Student.Version
  end
end
