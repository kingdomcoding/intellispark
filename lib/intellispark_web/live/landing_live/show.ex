defmodule IntellisparkWeb.LandingLive.Show do
  use IntellisparkWeb, :live_view

  @phase_rows [
    %{
      tag: "v0.1.0-phase-1-complete",
      date: ~D[2025-12-04],
      summary:
        "Auth + multi-tenancy via AshAuthentication; district/school/user model; PaperTrail everywhere.",
      slug: "phase-1-implementation"
    },
    %{
      tag: "v0.1.5-phase-1.5-complete",
      date: ~D[2025-12-10],
      summary: "Admin invitations + school invitation flow.",
      slug: "phase-1.5-school-invitations"
    },
    %{
      tag: "v0.2.0-phase-2-complete",
      date: ~D[2025-12-12],
      summary: "Students, tags, status transitions, custom lists with saved filters.",
      slug: "phase-2-students-tags-lists"
    },
    %{
      tag: "v0.3.0-phase-3-complete",
      date: ~D[2026-01-03],
      summary: "Student Hub — profile tab + timeline + roster cards.",
      slug: "phase-3-student-hub"
    },
    %{
      tag: "v0.3.5-phase-3.5-complete",
      date: ~D[2026-01-10],
      summary: "Hub Tab Framework — URL-driven ?tab= strip, mobile side-sheets.",
      slug: "phase-3.5-hub-tab-framework"
    },
    %{
      tag: "v0.4.0-phase-4-complete",
      date: ~D[2026-01-15],
      summary: "Flag workflow — open / check-up / close with resolution.",
      slug: "phase-4-flags"
    },
    %{
      tag: "v0.4.1-phase-4-retrofits-complete",
      date: ~D[2026-01-17],
      summary: "Phase 4 retrofits — inline check-up date input + red Close Flag button.",
      slug: "phase-4-retrofits"
    },
    %{
      tag: "v0.5.0-phase-5-complete",
      date: ~D[2026-01-24],
      summary: "Actions / Supports / Notes — per-student workflow cards.",
      slug: "phase-5-actions-supports-notes"
    },
    %{
      tag: "v0.6.0-phase-6-complete",
      date: ~D[2026-02-03],
      summary: "High 5s — public-token view + multi-recipient.",
      slug: "phase-6-high-fives"
    },
    %{
      tag: "v0.6.1-phase-6-retrofits-complete",
      date: ~D[2026-02-05],
      summary:
        "Phase 6 retrofits — rich-text editor + unified NewHighFiveModal + per-row resend.",
      slug: "phase-6-retrofits"
    },
    %{
      tag: "v0.6.5-phase-6.5-complete",
      date: ~D[2026-02-14],
      summary: "Branded emails + weekly digest + per-user email preferences.",
      slug: "phase-6.5-branded-emails-weekly-digest"
    },
    %{
      tag: "v0.7.0-phase-7-complete",
      date: ~D[2026-02-21],
      summary: "Surveys framework — AshStateMachine + per-question branching.",
      slug: "phase-7-surveys"
    },
    %{
      tag: "v0.8.0-phase-8-complete",
      date: ~D[2026-03-01],
      summary: "Insightfull + 13 SEL indicators — the computed signals layer.",
      slug: "phase-8-insightfull-indicators"
    },
    %{
      tag: "v0.9.0-phase-9-complete",
      date: ~D[2026-03-08],
      summary: "Insights view + filter DSL.",
      slug: "phase-9-insights-modal"
    },
    %{
      tag: "v0.10.0-phase-10-complete",
      date: ~D[2026-03-15],
      summary: "Teams, connections, strengths — polymorphic KeyConnection.",
      slug: "phase-10-teams-connections-strengths"
    },
    %{
      tag: "v0.10.5-phase-10.5-complete",
      date: ~D[2026-03-22],
      summary: "CustomList composer UI.",
      slug: "phase-10.5-custom-list-composer"
    },
    %{
      tag: "v0.11.0-phase-11-complete",
      date: ~D[2026-04-03],
      summary: "SIS ingestion + Xello bidirectional integration + Cloak vault.",
      slug: "phase-11-sis-xello-integration"
    },
    %{
      tag: "v0.11.5-phase-11.5-complete",
      date: ~D[2026-04-10],
      summary: "Student lifecycle — archive / transfer / mark withdrawn.",
      slug: "phase-11.5-student-lifecycle"
    },
    %{
      tag: "v0.14.0-scholarcentric-complete",
      date: ~D[2026-04-21],
      summary: "ScholarCentric + Academic Risk Index + About-the-Student tab.",
      slug: "phase-14-scholarcentric-about-student"
    },
    %{
      tag: "v0.15.0-deployment-complete",
      date: ~D[2026-04-23],
      summary:
        "Self-hosted prod deployment. Dockerized release + GitHub Actions CI/CD + GHCR + NPM TLS.",
      slug: "phase-18-deployment-cicd-infrastructure"
    }
  ]

  @domains [
    %{
      name: "Accounts",
      summary: "Districts, schools, users, memberships, invitations, demo sessions."
    },
    %{
      name: "Students",
      summary: "Student records, demographics, tags, status, notes, custom lists."
    },
    %{name: "Teams", summary: "Team members, key connections (polymorphic), strengths."},
    %{name: "Flags", summary: "Open / check-up / close workflow with resolutions."},
    %{name: "Support", summary: "Actions, supports, intervention library items."},
    %{name: "Recognition", summary: "High 5s — token-viewable, multi-recipient, rich-text."},
    %{name: "Assessments", summary: "Surveys framework + ScholarCentric resiliency."},
    %{name: "Indicators", summary: "Insightfull + 13-dimension SEL computed signals."},
    %{
      name: "Integrations",
      summary: "SIS ingestion, Xello bidirectional webhook, Cloak-encrypted credentials."
    },
    %{name: "Billing", summary: "Per-school subscription tiers, onboarding wizard, billing stub."}
  ]

  @stack [
    %{name: "Elixir 1.18.4 / OTP 27", detail: "Runtime."},
    %{name: "Phoenix 1.8", detail: "Router + endpoint + LiveDashboard."},
    %{name: "LiveView 1.1", detail: "Every interactive surface."},
    %{name: "Ash 3.24", detail: "Domain + policy + changeset + query DSL."},
    %{name: "AshPostgres 2.9", detail: "Multi-tenancy + migration generation."},
    %{name: "AshAuthentication 4.13", detail: "Password + token strategies; session plug."},
    %{
      name: "AshPaperTrail · AshArchival · AshStateMachine · AshOban",
      detail: "Audit, soft-delete, state machines, cron."
    },
    %{name: "PostgreSQL (host-shared)", detail: "Single instance serves dev + prod."},
    %{name: "Oban 2.21", detail: "Job queue for integrations + reminders."},
    %{name: "Cloak 1.1", detail: "AES-GCM at rest for integration credentials."},
    %{
      name: "Earmark · HtmlSanitizeEx · makeup_elixir",
      detail: "Markdown rendering for /engineering-journal."
    },
    %{name: "Phoenix LiveDashboard", detail: "Admin metrics at /admin/dashboard."},
    %{name: "GitHub Actions → GHCR → NPM", detail: "Self-hosted auto-deploy on push to main."}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Intellispark — Elixir/Phoenix/Ash portfolio")
     |> assign(:phase_rows, @phase_rows)
     |> assign(:domains, @domains)
     |> assign(:stack, @stack)
     |> assign(:proof, %{tests: 554, phases: length(@phase_rows), adrs: adr_count()})
     |> assign(:signed_in?, false)}
  end

  defp adr_count do
    Path.wildcard("docs/architecture/decisions/*.md") |> length()
  end
end
