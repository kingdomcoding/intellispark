require Logger

require Ash.Query

alias Intellispark.Accounts

alias Intellispark.Accounts.{
  District,
  School,
  SchoolInvitation,
  SchoolTerm,
  User,
  UserSchoolMembership
}

Logger.info("Seeding Sandbox district + schools + users…")

district =
  case District |> Ash.Query.filter(slug == "sandbox") |> Ash.read_one(authorize?: false) do
    {:ok, %District{} = d} ->
      d

    {:ok, nil} ->
      {:ok, d} =
        Accounts.create_district("Sandbox School District", "sandbox", authorize?: false)

      d
  end

ensure_school = fn name, slug ->
  case School
       |> Ash.Query.filter(district_id == ^district.id and slug == ^slug)
       |> Ash.read_one(authorize?: false) do
    {:ok, %School{} = s} ->
      s

    {:ok, nil} ->
      {:ok, s} = Accounts.create_school(name, slug, district.id, authorize?: false)
      s
  end
end

school = ensure_school.("Sandbox High School", "sandbox-high")
middle_school = ensure_school.("Sandbox Middle School", "sandbox-middle")

unless SchoolTerm
       |> Ash.Query.filter(school_id == ^school.id and name == "2026 Spring")
       |> Ash.read_one!(authorize?: false) do
  {:ok, _} =
    Accounts.create_term(
      "2026 Spring",
      ~D[2026-01-15],
      ~D[2026-06-15],
      true,
      school.id,
      authorize?: false
    )
end

ensure_membership = fn user, school_row, role ->
  unless UserSchoolMembership
         |> Ash.Query.filter(user_id == ^user.id and school_id == ^school_row.id)
         |> Ash.read_one!(authorize?: false) do
    {:ok, _} =
      Accounts.create_membership(user.id, school_row.id, role, :manual, authorize?: false)
  end

  :ok
end

ensure_user = fn email, memberships ->
  user =
    case User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one(authorize?: false) do
      {:ok, %User{} = u} ->
        u

      {:ok, nil} ->
        {:ok, u} =
          Ash.create(
            User,
            %{
              email: email,
              password: "phase1-demo-pass",
              password_confirmation: "phase1-demo-pass"
            },
            action: :register_with_password,
            authorize?: false
          )

        Ash.update!(u, %{district_id: district.id}, action: :set_district, authorize?: false)
    end

  Enum.each(memberships, fn {school_row, role} ->
    ensure_membership.(user, school_row, role)
  end)

  user
end

# Admin has memberships at BOTH schools so the header school-switcher
# dropdown is exercised on a fresh boot without manual SQL.
admin =
  ensure_user.("admin@sandboxhigh.edu", [
    {school, :admin},
    {middle_school, :admin}
  ])

_teacher = ensure_user.("curtis.murphy@sandboxhigh.edu", [{school, :teacher}])

# Seed one pending invitation so /admin has something to show on a fresh boot
# and the accept flow has a ready-made demo URL in /dev/mailbox.
demo_invite_email = "newcoach@sandboxhigh.edu"

existing_invite =
  SchoolInvitation
  |> Ash.Query.filter(email == ^demo_invite_email and school_id == ^school.id)
  |> Ash.read!(authorize?: false)

if Enum.empty?(existing_invite) do
  admin = Ash.load!(admin, [:school_memberships], authorize?: false)

  {:ok, invitation} =
    Accounts.invite_to_school(demo_invite_email, school.id, :counselor, actor: admin)

  Logger.info("  pending invite: #{demo_invite_email} as :counselor — email in /dev/mailbox")

  Logger.info("  invitation id: #{invitation.id}")
end

Logger.info("Seed complete.")
Logger.info("  admin login:   admin@sandboxhigh.edu / phase1-demo-pass")
Logger.info("  teacher login: curtis.murphy@sandboxhigh.edu / phase1-demo-pass")
