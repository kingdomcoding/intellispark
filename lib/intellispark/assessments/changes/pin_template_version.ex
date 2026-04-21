defmodule Intellispark.Assessments.Changes.PinTemplateVersion do
  @moduledoc false
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    template_id = Ash.Changeset.get_attribute(changeset, :survey_template_id)

    case Ash.get(Intellispark.Assessments.SurveyTemplate, template_id,
           tenant: changeset.tenant,
           authorize?: false
         ) do
      {:ok, %{current_version_id: nil}} ->
        Ash.Changeset.add_error(changeset,
          field: :survey_template_id,
          message: "template must be published before assigning"
        )

      {:ok, %{current_version_id: version_id}} ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :survey_template_version_id,
          version_id
        )

      _ ->
        Ash.Changeset.add_error(changeset,
          field: :survey_template_id,
          message: "template not found"
        )
    end
  end
end
