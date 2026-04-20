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

Logger.info("Seeding Phase 2 students, tags, statuses, lists…")

alias Intellispark.Students
alias Intellispark.Students.{CustomList, Status, Student, StudentTag, Tag}

ensure_student = fn attrs ->
  case Student
       |> Ash.Query.filter(external_id == ^attrs.external_id)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %Student{} = s} ->
      s

    {:ok, nil} ->
      {:ok, s} = Ash.create(Student, attrs, tenant: school.id, authorize?: false)
      s
  end
end

ensure_tag = fn name, color ->
  case Tag
       |> Ash.Query.filter(name == ^name)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %Tag{} = t} ->
      t

    {:ok, nil} ->
      {:ok, t} =
        Ash.create(Tag, %{name: name, color: color}, tenant: school.id, authorize?: false)

      t
  end
end

ensure_status = fn name, color, position ->
  case Status
       |> Ash.Query.filter(name == ^name)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %Status{} = s} ->
      s

    {:ok, nil} ->
      {:ok, s} =
        Ash.create(Status, %{name: name, color: color, position: position},
          tenant: school.id,
          authorize?: false
        )

      s
  end
end

ensure_student_tag = fn student, tag ->
  case Ash.create(StudentTag, %{student_id: student.id, tag_id: tag.id},
         tenant: school.id,
         actor: admin,
         authorize?: false
       ) do
    {:ok, _} -> :ok
    # Race-safe idempotency: the unique (school_id, student_id, tag_id)
    # index catches the re-seed case even when the pre-check read missed
    # the row (archival filter, replication lag, etc.).
    {:error, %{errors: [%{private_vars: vars} | _]}} ->
      if Keyword.get(vars || [], :constraint_type) == :unique do
        :ok
      else
        raise "unexpected ensure_student_tag error"
      end
  end
end

ensure_custom_list = fn name, filters, shared? ->
  case CustomList
       |> Ash.Query.filter(name == ^name and owner_id == ^admin.id)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %CustomList{} = l} ->
      l

    {:ok, nil} ->
      {:ok, l} =
        Ash.create(
          CustomList,
          %{name: name, filters: filters, shared?: shared?},
          tenant: school.id,
          actor: admin,
          authorize?: false
        )

      l
  end
end

ava =
  ensure_student.(%{
    first_name: "Ava",
    last_name: "Patel",
    grade_level: 10,
    enrollment_status: :active,
    external_id: "SH-0001"
  })

marcus =
  ensure_student.(%{
    first_name: "Marcus",
    last_name: "Johnson",
    grade_level: 11,
    enrollment_status: :active,
    external_id: "SH-0002"
  })

ling =
  ensure_student.(%{
    first_name: "Ling",
    last_name: "Chen",
    preferred_name: "Lily",
    grade_level: 9,
    enrollment_status: :active,
    external_id: "SH-0003"
  })

elena =
  ensure_student.(%{
    first_name: "Elena",
    last_name: "Ramirez",
    grade_level: 12,
    enrollment_status: :active,
    external_id: "SH-0004"
  })

noah =
  ensure_student.(%{
    first_name: "Noah",
    last_name: "Williams",
    grade_level: 9,
    enrollment_status: :inactive,
    external_id: "SH-0005"
  })

iep = ensure_tag.("IEP", "#14213D")
first_gen = ensure_tag.("1st Gen", "#A1452E")
academic_focus = ensure_tag.("Academic Focus", "#2B4366")

active = ensure_status.("Active", "#14A369", 0)
watch = ensure_status.("Watch", "#E5A73A", 1)
_withdrawn = ensure_status.("Withdrawn", "#4B4B4D", 2)

ensure_student_tag.(ava, iep)
ensure_student_tag.(ava, academic_focus)
ensure_student_tag.(marcus, first_gen)
ensure_student_tag.(ling, academic_focus)
ensure_student_tag.(elena, iep)
ensure_student_tag.(elena, first_gen)
ensure_student_tag.(noah, iep)

# Phase 3: give most seeded students a status so the Hub's status chip
# + ledger both have something to render. Guarded on current_status_id
# so re-running seeds doesn't open duplicate ledger rows.
ensure_status_for = fn student, status ->
  student =
    Student
    |> Ash.Query.filter(id == ^student.id)
    |> Ash.Query.set_tenant(school.id)
    |> Ash.read_one!(authorize?: false)

  if is_nil(student.current_status_id) do
    {:ok, _} =
      Students.set_student_status(student, status.id,
        actor: admin,
        tenant: school.id,
        authorize?: false
      )
  end
end

ensure_status_for.(ava, active)
ensure_status_for.(marcus, active)
ensure_status_for.(ling, active)
ensure_status_for.(elena, watch)
ensure_status_for.(noah, active)

# Give Ava a seeded photo so the hub's <img> branch is exercised on a
# fresh boot. The demo silhouette ships under priv/static/images/ so
# this path is stable across environments.
if is_nil(ava.photo_url) or ava.photo_url == "/images/demo-student.png" do
  {:ok, _} =
    Ash.update(ava, %{photo_url: "/images/demo-student.svg"},
      action: :update,
      tenant: school.id,
      actor: admin,
      authorize?: false
    )
end

_at_risk = ensure_custom_list.("At-risk (IEP)", %{tag_ids: [iep.id]}, true)

_seniors =
  ensure_custom_list.("Seniors graduating", %{grade_levels: [12]}, false)

Logger.info("Seed complete.")
Logger.info("  admin login:   admin@sandboxhigh.edu / phase1-demo-pass")
Logger.info("  teacher login: curtis.murphy@sandboxhigh.edu / phase1-demo-pass")
