defmodule Intellispark.Accounts do
  use Ash.Domain,
    otp_app: :intellispark,
    extensions: [AshAuthentication.Domain]

  resources do
    resource Intellispark.Accounts.User do
      define :list_users, action: :read
      define :get_user_by_id, action: :read, get_by: [:id]
      define :update_profile, action: :update_profile
    end

    resource Intellispark.Accounts.Token

    resource Intellispark.Accounts.District do
      define :create_district, action: :create, args: [:name, :slug]
      define :list_districts, action: :read
      define :get_district_by_id, action: :read, get_by: [:id]
    end

    resource Intellispark.Accounts.School do
      define :create_school, action: :create, args: [:name, :slug, :district_id]
      define :list_schools, action: :read
      define :get_school_by_id, action: :read, get_by: [:id]
    end

    resource Intellispark.Accounts.SchoolTerm do
      define :create_term,
        action: :create,
        args: [:name, :starts_on, :ends_on, :is_current?, :school_id]

      define :mark_current_term, action: :mark_current
    end

    resource Intellispark.Accounts.UserSchoolMembership do
      define :create_membership,
        action: :create,
        args: [:user_id, :school_id, :role, :source]

      define :list_memberships_for_user, action: :read
      define :update_membership_role, action: :update_role
    end

    resource Intellispark.Accounts.SchoolInvitation do
      define :invite_to_school, action: :invite, args: [:email, :school_id, :role]
      define :list_school_invitations, action: :read
      define :get_school_invitation_by_id, action: :read, get_by: [:id]

      define :accept_school_invitation,
        action: :accept_by_token,
        args: [:password, :password_confirmation, {:optional, :first_name}, {:optional, :last_name}]

      define :revoke_school_invitation, action: :revoke
    end

    resource Intellispark.Accounts.User.Version
    resource Intellispark.Accounts.District.Version
    resource Intellispark.Accounts.School.Version
    resource Intellispark.Accounts.SchoolTerm.Version
    resource Intellispark.Accounts.UserSchoolMembership.Version
    resource Intellispark.Accounts.SchoolInvitation.Version
  end
end
