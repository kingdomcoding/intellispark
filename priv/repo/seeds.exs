require Logger

require Ash.Query

alias Intellispark.Accounts
alias Intellispark.Accounts.{District, School, SchoolTerm, User, UserSchoolMembership}

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

school =
  case School
       |> Ash.Query.filter(district_id == ^district.id and slug == "sandbox-high")
       |> Ash.read_one(authorize?: false) do
    {:ok, %School{} = s} ->
      s

    {:ok, nil} ->
      {:ok, s} =
        Accounts.create_school("Sandbox High School", "sandbox-high", district.id,
          authorize?: false
        )

      s
  end

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

ensure_user = fn email, role ->
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

  unless UserSchoolMembership
         |> Ash.Query.filter(user_id == ^user.id and school_id == ^school.id)
         |> Ash.read_one!(authorize?: false) do
    {:ok, _} =
      Accounts.create_membership(user.id, school.id, role, :manual, authorize?: false)
  end

  user
end

ensure_user.("admin@sandboxhigh.edu", :admin)
ensure_user.("curtis.murphy@sandboxhigh.edu", :teacher)

Logger.info("Seed complete.")
Logger.info("  admin login:   admin@sandboxhigh.edu / phase1-demo-pass")
Logger.info("  teacher login: curtis.murphy@sandboxhigh.edu / phase1-demo-pass")
