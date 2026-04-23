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
      define :destroy_student, action: :destroy

      define :archive_student, action: :archive
      define :unarchive_student, action: :unarchive

      define :set_student_status, action: :set_status, args: [:status_id]
      define :clear_student_status, action: :clear_status
      define :upload_student_photo, action: :upload_photo, args: [:photo]
      define :remove_tag_from_student, action: :remove_tag, args: [:tag_id]
    end

    resource Intellispark.Students.Tag do
      define :list_tags, action: :read
      define :get_tag, action: :read, get_by: [:id]
      define :create_tag, action: :create, args: [:name, :color]
      define :update_tag, action: :update
      define :archive_tag, action: :destroy

      define :apply_tag_to_students,
        action: :apply_to_students,
        args: [:student_ids]
    end

    resource Intellispark.Students.StudentTag do
      define :list_student_tags, action: :read
      define :apply_tag, action: :create, args: [:student_id, :tag_id]
      define :remove_student_tag, action: :destroy
    end

    resource Intellispark.Students.Status do
      define :list_statuses, action: :read
      define :get_status, action: :read, get_by: [:id]
      define :create_status, action: :create, args: [:name, :color, :position]
      define :update_status, action: :update
      define :archive_status, action: :destroy
    end

    resource Intellispark.Students.StudentStatus do
      define :list_student_statuses, action: :read
    end

    resource Intellispark.Students.CustomList do
      define :list_custom_lists, action: :read
      define :get_custom_list, action: :read, get_by: [:id]
      define :create_custom_list, action: :create, args: [:name, :filters]
      define :update_custom_list, action: :update
      define :archive_custom_list, action: :destroy
      define :run_custom_list, action: :run, args: [:custom_list_id]
    end

    resource Intellispark.Students.Student.Version
    resource Intellispark.Students.Tag.Version
    resource Intellispark.Students.StudentTag.Version
    resource Intellispark.Students.Status.Version
    resource Intellispark.Students.StudentStatus.Version
    resource Intellispark.Students.CustomList.Version
  end
end
