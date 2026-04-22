defmodule Intellispark.Repo.Migrations.BackfillBillingState do
  use Ecto.Migration

  def up do
    execute("""
    INSERT INTO school_subscriptions
      (id, school_id, tier, status, seats, started_at, inserted_at, updated_at)
    SELECT gen_random_uuid(), s.id, 'starter', 'active', 0, NOW(), NOW(), NOW()
    FROM schools s
    LEFT JOIN school_subscriptions sub ON sub.school_id = s.id
    WHERE sub.id IS NULL
    """)

    execute("""
    INSERT INTO school_onboarding_states
      (id, school_id, current_step, completed_at, inserted_at, updated_at)
    SELECT gen_random_uuid(), s.id, 'done', NOW(), NOW(), NOW()
    FROM schools s
    LEFT JOIN school_onboarding_states os ON os.school_id = s.id
    WHERE os.id IS NULL
    """)
  end

  def down do
    execute("DELETE FROM school_onboarding_states")
    execute("DELETE FROM school_subscriptions")
  end
end
