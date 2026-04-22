defmodule Intellispark.Teams do
  @moduledoc """
  Domain for student relationship resources (Phase 10): TeamMembership
  (multi-role staff-student join), KeyConnection (meaningful staff
  relationships, often self-reported on surveys), and Strength
  (ordered bulleted list of student strengths). Phase 14 will add
  ExternalPerson for non-staff family / community contacts.
  """

  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Intellispark.Teams.TeamMembership do
      define :list_team_memberships, action: :read
      define :get_team_membership, action: :read, get_by: [:id]

      define :create_team_membership,
        action: :create,
        args: [:student_id, :user_id, :role]

      define :update_team_membership, action: :update
      define :destroy_team_membership, action: :destroy

      define :add_members_from_roster,
        action: :add_members_from_roster,
        args: [:student_id, :staff_user_ids, :role]
    end

    resource Intellispark.Teams.TeamMembership.Version
  end
end
