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

    resource Intellispark.Students.Tag do
      define :list_tags, action: :read
      define :get_tag, action: :read, get_by: [:id]
      define :create_tag, action: :create, args: [:name, :color]
      define :update_tag, action: :update
      define :archive_tag, action: :destroy
    end

    resource Intellispark.Students.StudentTag do
      define :list_student_tags, action: :read
      define :apply_tag, action: :create, args: [:student_id, :tag_id]
      define :remove_student_tag, action: :destroy
    end

    resource Intellispark.Students.Student.Version
    resource Intellispark.Students.Tag.Version
    resource Intellispark.Students.StudentTag.Version
  end
end
