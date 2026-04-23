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

# Fresh school that hasn't been onboarded yet — used to demo the
# /onboarding wizard + Get Started pill. Stays on :starter tier with
# `current_step: :school_profile` so the flow is visible for district
# admins whose `district_id` matches this district.
fresh_school = ensure_school.("Sandbox Elementary (Fresh)", "sandbox-elementary")

# Upgrade the 2 established demo schools to PRO tier so the switcher
# badge + tier-gated features are visible. Mark their onboarding state
# :done so the Get Started pill doesn't nag for them. Idempotent:
# pattern-matches on current state and no-ops when already set.
for s <- [school, middle_school] do
  case Intellispark.Billing.get_subscription_by_school(s.id,
         tenant: s.id,
         authorize?: false
       ) do
    {:ok, %{tier: :pro}} ->
      :ok

    {:ok, sub} ->
      {:ok, _} = Intellispark.Billing.set_tier(sub, :pro, tenant: s.id, authorize?: false)

    _ ->
      :ok
  end

  case Intellispark.Billing.get_onboarding_state_by_school(s.id,
         tenant: s.id,
         authorize?: false
       ) do
    {:ok, %{current_step: :done}} ->
      :ok

    {:ok, state} ->
      {:ok, _} = Intellispark.Billing.complete_onboarding(state, tenant: s.id, authorize?: false)

    _ ->
      :ok
  end
end

# Reset the fresh school's onboarding state back to :school_profile
# if a previous seeds run (or manual wizard walk-through) already
# advanced it. Leave its subscription on :starter — don't upgrade.
case Intellispark.Billing.get_onboarding_state_by_school(fresh_school.id,
       tenant: fresh_school.id,
       authorize?: false
     ) do
  {:ok, %{current_step: :school_profile, completed_at: nil}} ->
    :ok

  {:ok, state} ->
    {:ok, _} =
      state
      |> Ash.Changeset.for_update(
        :advance_step,
        %{step: :school_profile},
        authorize?: false,
        tenant: fresh_school.id
      )
      |> Ash.update()

    # Clear completed_at + step-specific timestamps so the wizard
    # starts fully clean. Use a direct Repo update since there's
    # no resource action that resets stamps.
    Intellispark.Repo.query!(
      """
      UPDATE school_onboarding_states
         SET completed_at = NULL,
             school_profile_completed_at = NULL,
             invite_coadmins_completed_at = NULL,
             starter_tags_completed_at = NULL,
             sis_provider_completed_at = NULL,
             pick_tier_completed_at = NULL
       WHERE school_id = $1
      """,
      [Ecto.UUID.dump!(fresh_school.id)]
    )

  _ ->
    :ok
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

# Admin has memberships at all three schools so the header school-
# switcher dropdown is exercised on a fresh boot, and switching to the
# fresh school surfaces the onboarding wizard.
admin =
  ensure_user.("admin@sandboxhigh.edu", [
    {school, :admin},
    {middle_school, :admin},
    {fresh_school, :admin}
  ])

curtis = ensure_user.("curtis.murphy@sandboxhigh.edu", [{school, :teacher}])

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
      # Backfill email on previously-seeded students (Phase 6 added the column).
      if is_nil(s.email) and Map.get(attrs, :email) do
        {:ok, updated} =
          Ash.update(s, %{email: attrs.email},
            action: :update,
            tenant: school.id,
            authorize?: false
          )

        updated
      else
        s
      end

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
    {:ok, _} ->
      :ok

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
    external_id: "SH-0001",
    email: "ava.patel@example.com"
  })

marcus =
  ensure_student.(%{
    first_name: "Marcus",
    last_name: "Johnson",
    grade_level: 11,
    enrollment_status: :active,
    external_id: "SH-0002",
    email: "marcus.johnson@example.com"
  })

ling =
  ensure_student.(%{
    first_name: "Ling",
    last_name: "Chen",
    preferred_name: "Lily",
    grade_level: 9,
    enrollment_status: :active,
    external_id: "SH-0003",
    email: "ling.chen@example.com"
  })

elena =
  ensure_student.(%{
    first_name: "Elena",
    last_name: "Ramirez",
    grade_level: 12,
    enrollment_status: :active,
    external_id: "SH-0004",
    email: "elena.ramirez@example.com"
  })

noah =
  ensure_student.(%{
    first_name: "Noah",
    last_name: "Williams",
    grade_level: 9,
    enrollment_status: :inactive,
    external_id: "SH-0005",
    email: "noah.williams@example.com"
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

Logger.info("Seeding Phase 4 flag types + demo flags…")

alias Intellispark.Flags
alias Intellispark.Flags.{Flag, FlagType}

ensure_flag_type = fn name, color, sensitive? ->
  case Ash.create(
         FlagType,
         %{name: name, color: color, default_sensitive?: sensitive?},
         tenant: school.id,
         actor: admin,
         authorize?: false
       ) do
    {:ok, ft} ->
      ft

    {:error, %{errors: [%{private_vars: vars} | _]}} ->
      if Keyword.get(vars || [], :constraint_type) == :unique do
        {:ok, ft} =
          FlagType
          |> Ash.Query.filter(name == ^name)
          |> Ash.Query.set_tenant(school.id)
          |> Ash.read_one(authorize?: false)

        ft
      else
        raise "unexpected ensure_flag_type error"
      end
  end
end

ensure_flag_for = fn student, type, desc, opts ->
  short = String.slice(desc, 0, 80)

  case Flag
       |> Ash.Query.filter(student_id == ^student.id and short_description == ^short)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %Flag{}} ->
      :ok

    {:ok, nil} ->
      {:ok, draft} =
        Flags.create_flag(student.id, type.id, desc,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      {:ok, opened} =
        Flags.open_flag(draft, [admin.id],
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      if opts[:pending_followup?] do
        {:ok, _} =
          Flags.set_flag_followup(opened, Date.utc_today(),
            actor: admin,
            tenant: school.id,
            authorize?: false
          )
      end

      :ok
  end
end

flag_types_map = %{
  academic: ensure_flag_type.("Academic", "#2B4366", false),
  attendance: ensure_flag_type.("Attendance", "#E5A73A", false),
  behavioral: ensure_flag_type.("Behavioral", "#A1452E", false),
  mental_health: ensure_flag_type.("Mental health", "#4B4B4D", true),
  family: ensure_flag_type.("Family", "#14A369", true)
}

ensure_flag_for.(
  marcus,
  flag_types_map.academic,
  "Missing homework for 3 consecutive weeks. Parent contact made.",
  []
)

ensure_flag_for.(
  elena,
  flag_types_map.attendance,
  "Three absences in the past week.",
  pending_followup?: true
)

Logger.info("Seeding Phase 5 actions + supports + notes…")

alias Intellispark.Support
alias Intellispark.Support.{Action, Note}
alias Intellispark.Support.Support, as: SupportPlan

ensure_action_for = fn student, assignee, desc, due_on ->
  case Action
       |> Ash.Query.filter(student_id == ^student.id and description == ^desc)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %Action{}} ->
      :ok

    {:ok, nil} ->
      attrs = %{
        student_id: student.id,
        assignee_id: assignee.id,
        description: desc,
        due_on: due_on
      }

      {:ok, _} =
        Action
        |> Ash.Changeset.for_create(:create, attrs, tenant: school.id, actor: admin)
        |> Ash.create(authorize?: false)

      :ok
  end
end

ensure_action_for.(
  marcus,
  admin,
  "Check in on tutoring support",
  Date.add(Date.utc_today(), 7)
)

ensure_action_for.(
  elena,
  admin,
  "Schedule attendance meeting with parents",
  Date.utc_today()
)

ensure_support_for = fn student, title, desc, days_out ->
  case SupportPlan
       |> Ash.Query.filter(student_id == ^student.id and title == ^title)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %SupportPlan{}} ->
      :ok

    {:ok, nil} ->
      attrs = %{
        student_id: student.id,
        title: title,
        description: desc,
        starts_at: Date.utc_today(),
        ends_at: Date.add(Date.utc_today(), days_out)
      }

      {:ok, _} =
        SupportPlan
        |> Ash.Changeset.for_create(:create, attrs, tenant: school.id, actor: admin)
        |> Ash.create(authorize?: false)

      :ok
  end
end

ensure_support_for.(ava, "Academic Focus Plan", "Weekly check-ins + tutoring", 30)
ensure_support_for.(marcus, "Flex Time Pass", nil, 14)

ensure_note_for = fn student, body, pinned? ->
  case Note
       |> Ash.Query.filter(student_id == ^student.id and body == ^body)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %Note{}} ->
      :ok

    {:ok, nil} ->
      {:ok, note} =
        Support.create_note(student.id, body,
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      if pinned? do
        {:ok, _} =
          Support.pin_note(note,
            actor: admin,
            tenant: school.id,
            authorize?: false
          )
      end

      :ok
  end
end

ensure_note_for.(
  marcus,
  "Met with parents on 4/19. Signed off on the tutoring plan.",
  true
)

ensure_note_for.(
  marcus,
  "Homework showing up more consistently this week.",
  false
)

Logger.info("Seeding Phase 6 High 5 templates + demo high fives…")

alias Intellispark.Recognition.HighFive, as: HighFivePhase6
alias Intellispark.Recognition.HighFiveTemplate

ensure_template = fn title, body, category ->
  case HighFiveTemplate
       |> Ash.Query.filter(title == ^title)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %HighFiveTemplate{} = t} ->
      t

    {:ok, nil} ->
      {:ok, t} =
        HighFiveTemplate
        |> Ash.Changeset.for_create(
          :create,
          %{title: title, body: body, category: category},
          tenant: school.id,
          actor: admin
        )
        |> Ash.create(authorize?: false)

      t
  end
end

hf_templates = %{
  achievement:
    ensure_template.(
      "Great class participation today!",
      "Congrats on great class participation in today's class.",
      :achievement
    ),
  effort:
    ensure_template.(
      "So proud of you!",
      "So proud of your improved attendance this week. You are such an important member of the class and your comments are brilliant!",
      :effort
    ),
  kindness:
    ensure_template.(
      "Saw you help a classmate",
      "Noticed you stopping to help a classmate today — thank you for being that kind of student!",
      :kindness
    ),
  behavior:
    ensure_template.(
      "Strong focus today",
      "You stayed on task the entire period today. That kind of focus is rare and impressive.",
      :behavior
    ),
  attendance:
    ensure_template.(
      "Perfect attendance this week",
      "Five days this week — you're showing up and that's huge.",
      :attendance
    )
}

ensure_high_five = fn student, template, days_ago ->
  case HighFivePhase6
       |> Ash.Query.filter(student_id == ^student.id and title == ^template.title)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %HighFivePhase6{}} ->
      :ok

    {:ok, nil} ->
      {:ok, _hf} =
        HighFivePhase6
        |> Ash.Changeset.for_create(
          :send_to_student,
          %{
            student_id: student.id,
            title: template.title,
            body: template.body,
            template_id: template.id,
            recipient_email: "#{student.first_name |> String.downcase()}@example.com"
          },
          tenant: school.id,
          actor: admin
        )
        |> Ash.Changeset.force_change_attribute(
          :sent_at,
          DateTime.add(DateTime.utc_now(), -days_ago * 86_400, :second)
        )
        |> Ash.create(authorize?: false)

      :ok
  end
end

ensure_high_five.(marcus, hf_templates.achievement, 4)
ensure_high_five.(marcus, hf_templates.effort, 2)

Logger.info("Seeding Phase 7 Get to Know Me survey…")

alias Intellispark.Assessments
alias Intellispark.Assessments.SurveyTemplate, as: SurveyTemplatePhase7

{get_to_know_me, gtkm_created?} =
  case SurveyTemplatePhase7
       |> Ash.Query.filter(name == "Get to Know Me")
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %SurveyTemplatePhase7{} = t} ->
      {t, false}

    {:ok, nil} ->
      {:ok, t} =
        Assessments.create_survey_template(
          "Get to Know Me",
          "A quick profile to help your teachers know you better.",
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      {t, true}
  end

if gtkm_created? do
  questions = [
    {1, "What name do you like to be called?", :short_text, false, %{}},
    {2, "What are your favorite subjects in school?", :short_text, false, %{}},
    {3, "What are your least favorite subjects in school?", :short_text, false, %{}},
    {4, "I learn the most when the teacher...", :short_text, true, %{}},
    {5, "When you think of the best class you have ever taken, what about it made it the best?",
     :long_text, true, %{}},
    {6, "What are your hobbies outside of school?", :short_text, false, %{}},
    {7, "What would you like your teachers to know about you?", :long_text, false, %{}},
    {8, "Who are the adults at home who help you with school?", :short_text, false, %{}},
    {9, "What are you most looking forward to this school year?", :long_text, false, %{}}
  ]

  for {pos, prompt, type, required?, meta} <- questions do
    Assessments.create_survey_question(
      get_to_know_me.id,
      pos,
      prompt,
      type,
      %{required?: required?, metadata: meta},
      actor: admin,
      tenant: school.id,
      authorize?: false
    )
  end

  {:ok, _} =
    Assessments.publish_survey_template(get_to_know_me,
      actor: admin,
      tenant: school.id,
      authorize?: false
    )
end

marcus_gtkm_assignment =
  Intellispark.Assessments.SurveyAssignment
  |> Ash.Query.filter(student_id == ^marcus.id and survey_template_id == ^get_to_know_me.id)
  |> Ash.Query.set_tenant(school.id)
  |> Ash.read_one!(authorize?: false)

if is_nil(marcus_gtkm_assignment) do
  get_to_know_me =
    Ash.load!(get_to_know_me, :current_version, tenant: school.id, authorize?: false)

  {:ok, _} =
    Assessments.assign_survey(marcus.id, get_to_know_me.id,
      actor: admin,
      tenant: school.id,
      authorize?: false
    )
end

Logger.info("Seeding Phase 8 Insightfull survey…")

insightfull_items = [
  {"I feel like I belong at my school.", :belonging},
  {"I feel accepted by other students here.", :belonging},
  {"I feel close to people at my school.", :connection},
  {"There is an adult at school I can talk to if I need help.", :connection},
  {"Before making a decision, I think about the consequences.", :decision_making},
  {"I consider different options before making a choice.", :decision_making},
  {"I get excited about what I'm learning in class.", :engagement},
  {"I put effort into my schoolwork.", :engagement},
  {"I come to class prepared and ready to learn.", :readiness},
  {"I get enough sleep to be ready for school.", :readiness},
  {"I handle disagreements with others in a healthy way.", :relationship_skills},
  {"I work well with classmates on group projects.", :relationship_skills},
  {"I have adults in my life I can rely on.", :relationships_adult},
  {"There is a teacher who knows me well.", :relationships_adult},
  {"I have people who support me outside of school.", :relationships_networks},
  {"I'm part of a community that cares about me.", :relationships_networks},
  {"I have friends my age I can count on.", :relationships_peer},
  {"I feel understood by my friends.", :relationships_peer},
  {"I know what I am good at.", :self_awareness},
  {"I recognise how my emotions affect my choices.", :self_awareness},
  {"I can calm myself down when I'm upset.", :self_management},
  {"I stay focused on what I need to do, even when it's hard.", :self_management},
  {"I try to understand how others feel.", :social_awareness},
  {"I notice when someone around me is having a hard time.", :social_awareness},
  {"Overall, I feel good about my life.", :well_being},
  {"I feel energetic most days.", :well_being}
]

{insightfull, insightfull_created?} =
  case SurveyTemplatePhase7
       |> Ash.Query.filter(name == "Insightfull")
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, %SurveyTemplatePhase7{} = t} ->
      {t, false}

    {:ok, nil} ->
      {:ok, t} =
        Assessments.create_survey_template(
          "Insightfull",
          "A quick self-check on how you're feeling about school + your relationships.",
          actor: admin,
          tenant: school.id,
          authorize?: false
        )

      {t, true}
  end

if insightfull_created? do
  insightfull_items
  |> Enum.with_index(1)
  |> Enum.each(fn {{prompt, dimension}, pos} ->
    Assessments.create_survey_question(
      insightfull.id,
      pos,
      prompt,
      :dimension_rating,
      %{
        required?: true,
        metadata: %{
          "dimension" => Atom.to_string(dimension),
          "scale_labels" => ["Never", "Rarely", "Sometimes", "Often", "Always"]
        }
      },
      actor: admin,
      tenant: school.id,
      authorize?: false
    )
  end)

  {:ok, _} =
    Assessments.publish_survey_template(insightfull,
      actor: admin,
      tenant: school.id,
      authorize?: false
    )
end

marcus_insightfull_assignment =
  Intellispark.Assessments.SurveyAssignment
  |> Ash.Query.filter(student_id == ^marcus.id and survey_template_id == ^insightfull.id)
  |> Ash.Query.set_tenant(school.id)
  |> Ash.read_one!(authorize?: false)

if is_nil(marcus_insightfull_assignment) do
  insightfull =
    Ash.load!(insightfull, :current_version, tenant: school.id, authorize?: false)

  {:ok, _} =
    Assessments.assign_survey(marcus.id, insightfull.id,
      actor: admin,
      tenant: school.id,
      authorize?: false
    )
end

Logger.info("Seeding Phase 10 teams, connections, strengths…")

alias Intellispark.Teams
alias Intellispark.Teams.{KeyConnection, Strength, TeamMembership}

ensure_strength = fn student, description ->
  existing =
    Strength
    |> Ash.Query.filter(student_id == ^student.id and description == ^description)
    |> Ash.Query.set_tenant(school.id)
    |> Ash.read_one!(authorize?: false)

  if is_nil(existing) do
    {:ok, _} =
      Teams.create_strength(student.id, description,
        actor: admin,
        tenant: school.id,
        authorize?: false
      )
  end
end

ensure_strength.(marcus, "Creativity")
ensure_strength.(marcus, "Relationship building")

existing_team =
  TeamMembership
  |> Ash.Query.filter(student_id == ^marcus.id and user_id == ^curtis.id and role == :coach)
  |> Ash.Query.set_tenant(school.id)
  |> Ash.read_one!(authorize?: false)

if is_nil(existing_team) do
  {:ok, _} =
    Teams.create_team_membership(marcus.id, curtis.id, :coach,
      actor: admin,
      tenant: school.id,
      authorize?: false
    )
end

existing_connection =
  KeyConnection
  |> Ash.Query.filter(student_id == ^marcus.id and connected_user_id == ^curtis.id)
  |> Ash.Query.set_tenant(school.id)
  |> Ash.read_one!(authorize?: false)

if is_nil(existing_connection) do
  {:ok, _} =
    Teams.create_key_connection(
      marcus.id,
      curtis.id,
      %{note: "self-reported on Insightfull", source: :self_reported},
      actor: admin,
      tenant: school.id,
      authorize?: false
    )
end

Logger.info("Seeding Phase 11 integrations (CSV + Xello providers, sync runs, embed token)…")

alias Intellispark.Integrations
alias Intellispark.Integrations.{EmbedToken, IntegrationProvider, IntegrationSyncRun}

# Seed CSV + Xello providers on every school whose subscription is :pro
# so multi-school admins see content on /admin/integrations regardless
# of their current switcher selection. Starter-tier schools get nothing.
phase_11_schools = [school, middle_school]

for sch <- phase_11_schools do
  csv_p =
    case IntegrationProvider
         |> Ash.Query.filter(provider_type == :csv)
         |> Ash.Query.set_tenant(sch.id)
         |> Ash.read_one(authorize?: false) do
      {:ok, %IntegrationProvider{} = p} ->
        p

      {:ok, nil} ->
        {:ok, p} =
          Integrations.create_provider(
            %{provider_type: :csv, name: "Roster CSV", credentials: %{}},
            tenant: sch.id,
            authorize?: false
          )

        p
    end

  case Intellispark.Billing.get_subscription_by_school!(sch.id,
         tenant: sch.id,
         authorize?: false
       ) do
    %{tier: :pro} ->
      case IntegrationProvider
           |> Ash.Query.filter(provider_type == :xello)
           |> Ash.Query.set_tenant(sch.id)
           |> Ash.read_one(authorize?: false) do
        {:ok, %IntegrationProvider{}} ->
          :ok

        {:ok, nil} ->
          {:ok, _} =
            Integrations.create_provider(
              %{
                provider_type: :xello,
                name: "Xello (demo)",
                credentials: %{"webhook_secret" => "dev-xello-secret"}
              },
              tenant: sch.id,
              authorize?: false
            )
      end

    _ ->
      :ok
  end

  # A completed sync run per CSV provider so /admin/integrations shows
  # activity history on first boot. Idempotent.
  case IntegrationSyncRun
       |> Ash.Query.filter(provider_id == ^csv_p.id)
       |> Ash.Query.set_tenant(sch.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, nil} ->
      {:ok, run} =
        Ash.create(
          IntegrationSyncRun,
          %{provider_id: csv_p.id, trigger_source: :manual},
          tenant: sch.id,
          authorize?: false
        )

      {:ok, started} =
        Ash.update(run, %{}, action: :start, tenant: sch.id, authorize?: false)

      {:ok, _} =
        Ash.update(
          started,
          %{records_processed: 5, records_created: 2, records_updated: 3},
          action: :succeed,
          tenant: sch.id,
          authorize?: false
        )

    _ ->
      :ok
  end
end

# Mint an embed token for Ava on Sandbox High so the /embed demo URL is
# ready to paste into an iframe. The DistrictAdminForSchoolScopedCreate
# policy reads `actor.school_memberships`, so preload them.
admin_with_memberships = Ash.load!(admin, [:school_memberships], authorize?: false)

existing_embed =
  case EmbedToken
       |> Ash.Query.filter(student_id == ^ava.id and audience == :xello)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, et} -> et
    _ -> nil
  end

if existing_embed == nil do
  {:ok, token} =
    Integrations.mint_embed_token(
      %{student_id: ava.id, audience: :xello},
      actor: admin_with_memberships,
      tenant: school.id
    )

  Logger.info("  embed URL:     http://localhost:4800/embed/student/#{token.token}")
else
  Logger.info("  embed URL:     http://localhost:4800/embed/student/#{existing_embed.token}")
end

for pro_school <- [school, middle_school] do
  library_seeds = [
    %{
      title: "Flex Time Pass",
      mtss_tier: :tier_2,
      default_duration_days: 30,
      description: "Twice-weekly mentor check-in during flex block."
    },
    %{
      title: "Tier 2 Reading Group",
      mtss_tier: :tier_2,
      default_duration_days: 60,
      description: "Small-group phonics + comprehension, 3x/week."
    },
    %{
      title: "Check & Connect",
      mtss_tier: :tier_3,
      default_duration_days: 90,
      description: "Daily student-mentor relationship + attendance monitoring."
    },
    %{
      title: "Counseling Referral",
      mtss_tier: :tier_3,
      default_duration_days: 60,
      description: "Weekly individual counseling session with school counselor."
    },
    %{
      title: "Attendance Contract",
      mtss_tier: :tier_2,
      default_duration_days: 45,
      description: "Attendance goal tracker signed by student + parent + advisor."
    },
    %{
      title: "Academic Coaching",
      mtss_tier: :tier_1,
      default_duration_days: 30,
      description: "Weekly study-skills coaching session."
    }
  ]

  for attrs <- library_seeds do
    existing =
      case Intellispark.Support.InterventionLibraryItem
           |> Ash.Query.filter(title == ^attrs.title)
           |> Ash.Query.set_tenant(pro_school.id)
           |> Ash.read_one(authorize?: false) do
        {:ok, item} -> item
        _ -> nil
      end

    if is_nil(existing) do
      Ash.create!(
        Intellispark.Support.InterventionLibraryItem,
        attrs,
        tenant: pro_school.id,
        authorize?: false
      )
    end
  end

  Logger.info("  interventions: #{pro_school.name} — 6 library items")
end

existing_xello =
  case Intellispark.Integrations.XelloProfile
       |> Ash.Query.filter(student_id == ^ava.id)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, xp} -> xp
    _ -> nil
  end

if is_nil(existing_xello) do
  {:ok, _} =
    Intellispark.Integrations.upsert_xello_profile(
      %{
        student_id: ava.id,
        personality_style: %{"helper" => 0.5, "organizer" => 0.3, "persuader" => 0.2},
        learning_style: %{"visual" => 55, "auditory" => 25, "tactile" => 20},
        education_goals: "Go to college",
        favorite_career_clusters: ["STEM", "Healthcare", "Human Services"],
        skills: ["Communication", "Problem solving", "Teamwork"],
        interests: ["Biology", "Art", "Music"],
        birthplace: "California",
        live_in: "Massachusetts",
        family_roots: "Indian",
        suggested_clusters: ["Healthcare", "Education"],
        completed_lessons: ["L1", "L2", "L3"]
      },
      tenant: school.id,
      authorize?: false
    )

  Logger.info("  xello:         Ava Patel — profile synced")
end

existing_resiliency =
  case Intellispark.Assessments.Resiliency.Assessment
       |> Ash.Query.filter(student_id == ^ava.id and state == :submitted)
       |> Ash.Query.set_tenant(school.id)
       |> Ash.read_one(authorize?: false) do
    {:ok, a} -> a
    _ -> nil
  end

school_with_sub = Ash.load!(school, [:subscription], authorize?: false)
actor_with_school = Map.put(admin_with_memberships, :current_school, school_with_sub)

if is_nil(existing_resiliency) do
  {:ok, assignment} =
    Intellispark.Assessments.assign_resiliency(ava.id, :grades_9_12,
      actor: actor_with_school,
      tenant: school.id
    )

  skill_values = %{
    confidence: 2,
    persistence: 3,
    organization: 4,
    getting_along: 4,
    resilience: 3,
    curiosity: 4
  }

  for q <- Intellispark.Assessments.Resiliency.QuestionBank.questions_for(:grades_9_12) do
    value = Map.get(skill_values, q.skill, 3)

    {:ok, _} =
      Intellispark.Assessments.upsert_resiliency_response(
        assignment.id,
        q.id,
        value,
        tenant: school.id,
        authorize?: false
      )
  end

  {:ok, _} =
    Intellispark.Assessments.submit_resiliency(assignment,
      actor: actor_with_school,
      tenant: school.id
    )

  Intellispark.Assessments.Resiliency.Workers.SkillScoreWorker.perform(%Oban.Job{
    args: %{"assessment_id" => assignment.id, "tenant" => school.id}
  })

  Logger.info("  resiliency:    Ava Patel — 6 skills scored")
end

Logger.info("Seed complete.")
Logger.info("  admin login:   admin@sandboxhigh.edu / phase1-demo-pass")
Logger.info("  teacher login: curtis.murphy@sandboxhigh.edu / phase1-demo-pass")
