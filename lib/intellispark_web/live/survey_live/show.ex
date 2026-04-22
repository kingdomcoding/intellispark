defmodule IntellisparkWeb.SurveyLive.Show do
  @moduledoc """
  Student-facing survey LiveView. Token-authenticated (token is in the
  URL). Renders one question per page with a progress bar; auto-saves
  responses on blur / on-change; submit finalises the assignment.
  """

  use IntellisparkWeb, :live_view

  alias Intellispark.Assessments

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Assessments.get_survey_assignment_by_token(token, authorize?: false) do
      {:ok, assignment} ->
        hydrated =
          Ash.load!(
            assignment,
            [:survey_template_version, :survey_template, :responses],
            tenant: assignment.school_id,
            authorize?: false
          )

        questions =
          (hydrated.survey_template_version.schema["questions"] || [])
          |> Enum.sort_by(fn q -> q["position"] end)

        responses_by_q = responses_map(hydrated.responses || [])

        {:ok,
         socket
         |> assign(
           assignment: hydrated,
           questions: questions,
           responses_by_q: responses_by_q,
           current_index: 0,
           not_found?: false,
           submitted?: hydrated.state == :submitted,
           expired?: hydrated.state == :expired,
           submit_error: nil,
           page_title: hydrated.survey_template_version.schema["name"] || "Survey"
         )}

      _ ->
        {:ok,
         socket
         |> assign(
           assignment: nil,
           questions: [],
           responses_by_q: %{},
           current_index: 0,
           not_found?: true,
           submitted?: false,
           expired?: false,
           submit_error: nil,
           page_title: "Survey not found"
         )}
    end
  end

  @impl true
  def handle_event("save_answer", %{"question_id" => qid, "answer_text" => text}, socket) do
    save_and_stay(socket, qid, text, [])
  end

  def handle_event("save_answer", %{"question_id" => qid, "value" => text}, socket) do
    save_and_stay(socket, qid, text, [])
  end

  def handle_event("save_values", params, socket) do
    qid = Map.fetch!(params, "question_id")
    vs = params["answer_values"] || []
    save_and_stay(socket, qid, nil, vs)
  end

  def handle_event("next", _params, socket) do
    last = length(socket.assigns.questions) - 1

    {:noreply,
     assign(socket,
       current_index: min(socket.assigns.current_index + 1, last),
       submit_error: nil
     )}
  end

  def handle_event("previous", _params, socket) do
    {:noreply,
     assign(socket,
       current_index: max(socket.assigns.current_index - 1, 0),
       submit_error: nil
     )}
  end

  def handle_event("submit", _params, socket) do
    a = socket.assigns.assignment

    case Assessments.submit_survey(a, tenant: a.school_id, authorize?: false) do
      {:ok, _} ->
        {:noreply, assign(socket, submitted?: true, submit_error: nil)}

      {:error, _err} ->
        missing =
          missing_required_prompts(
            socket.assigns.questions,
            socket.assigns.responses_by_q
          )

        {:noreply, assign(socket, submit_error: %{missing: missing})}
    end
  end

  defp save_and_stay(socket, qid, text, values) do
    a = socket.assigns.assignment

    case Assessments.save_survey_progress(a, qid, text, values,
           tenant: a.school_id,
           authorize?: false
         ) do
      {:ok, _} ->
        new_map =
          Map.put(socket.assigns.responses_by_q, qid, %{
            "answer_text" => text,
            "answer_values" => values
          })

        {:noreply, assign(socket, responses_by_q: new_map, submit_error: nil)}

      {:error, _err} ->
        {:noreply, socket}
    end
  end

  defp missing_required_prompts(questions, responses_by_q) do
    questions
    |> Enum.filter(& &1["required?"])
    |> Enum.reject(&answered?(responses_by_q, &1["id"]))
    |> Enum.map(& &1["prompt"])
  end

  defp answered?(map, qid) do
    case Map.get(map, qid) do
      %{"answer_text" => t} when is_binary(t) and t != "" -> true
      %{"answer_values" => vs} when is_list(vs) and vs != [] -> true
      _ -> false
    end
  end

  defp responses_map(responses) do
    Enum.reduce(responses, %{}, fn r, acc ->
      Map.put(acc, r.question_id, %{
        "answer_text" => r.answer_text,
        "answer_values" => r.answer_values || []
      })
    end)
  end

  @impl true
  def render(%{not_found?: true} = assigns) do
    ~H"""
    <main class="survey-gradient flex items-center justify-center p-md">
      <.fallback_card
        title="Survey not found"
        body="We couldn't find this survey. The link may have expired or been sent in error."
      />
    </main>
    """
  end

  def render(%{submitted?: true} = assigns) do
    ~H"""
    <main class="survey-gradient flex items-center justify-center p-md">
      <.fallback_card
        title="Thanks for your response!"
        body="Your answers have been saved. You can close this tab."
      />
    </main>
    """
  end

  def render(%{expired?: true} = assigns) do
    ~H"""
    <main class="survey-gradient flex items-center justify-center p-md">
      <.fallback_card
        title="This survey has expired"
        body="Please check with your school for a new invitation."
      />
    </main>
    """
  end

  def render(assigns) do
    current_q = Enum.at(assigns.questions, assigns.current_index)
    total = length(assigns.questions)
    answered = answered_count(assigns.responses_by_q, assigns.questions)

    assigns =
      assign(assigns,
        current_q: current_q,
        total: total,
        answered: answered,
        current_answer: current_answer(assigns.responses_by_q, current_q),
        last?: assigns.current_index == total - 1
      )

    ~H"""
    <main class="survey-gradient flex items-center justify-center p-md">
      <div class="container-sm bg-white rounded-card shadow-elevated p-lg space-y-md">
        <.progress_bar answered={@answered} total={@total} />

        <.submit_error_banner :if={@submit_error} error={@submit_error} />

        <.question_card question={@current_q} current={@current_answer} />

        <div class="flex items-center justify-between pt-md">
          <.button
            :if={@current_index > 0}
            type="button"
            variant={:ghost}
            phx-click="previous"
          >
            Previous
          </.button>
          <span :if={@current_index == 0}></span>

          <.button :if={not @last?} type="button" variant={:primary} phx-click="next">
            Next
          </.button>
          <.button :if={@last?} type="button" variant={:primary} phx-click="submit">
            Submit
          </.button>
        </div>
      </div>
    </main>
    """
  end

  attr :error, :map, required: true

  defp submit_error_banner(assigns) do
    ~H"""
    <div
      role="alert"
      class="rounded-card border border-chocolate bg-chocolate/5 p-sm space-y-xs"
    >
      <p class="text-sm font-semibold text-chocolate">
        Please answer all required questions before submitting.
      </p>
      <ul :if={@error[:missing] != []} class="list-disc pl-lg text-sm text-chocolate">
        <li :for={prompt <- @error[:missing]}>{prompt}</li>
      </ul>
    </div>
    """
  end

  attr :answered, :integer, required: true
  attr :total, :integer, required: true

  defp progress_bar(assigns) do
    pct =
      if assigns.total == 0, do: 0, else: round(100 * assigns.answered / assigns.total)

    assigns = assign(assigns, pct: pct)

    ~H"""
    <div class="space-y-xs">
      <p class="text-xs font-semibold text-brand">{@answered} of {@total} answered</p>
      <div class="w-full h-1 bg-abbey/10 rounded-full overflow-hidden">
        <div class="h-full bg-brand transition-all" style={"width: #{@pct}%"}></div>
      </div>
    </div>
    """
  end

  attr :question, :map, required: true
  attr :current, :map, required: true

  defp question_card(assigns) do
    ~H"""
    <div class="space-y-sm">
      <p class="text-md font-medium text-abbey">
        {@question["prompt"]}
        <span :if={@question["required?"]} class="text-azure text-sm">(required)</span>
      </p>
      <p :if={@question["help_text"]} class="text-xs text-azure">
        {@question["help_text"]}
      </p>

      <.answer_input question={@question} current={@current} />
    </div>
    """
  end

  attr :question, :map, required: true
  attr :current, :map, required: true

  defp answer_input(%{question: %{"question_type" => type}} = assigns)
       when type in ~w(short_text long_text) do
    rows = if type == "long_text", do: "5", else: "1"
    assigns = assign(assigns, rows: rows)

    ~H"""
    <form phx-change="save_answer" class="w-full">
      <input type="hidden" name="question_id" value={@question["id"]} />
      <textarea
        name="answer_text"
        rows={@rows}
        placeholder="Type your answer here.."
        phx-blur="save_answer"
        phx-value-question_id={@question["id"]}
        class="w-full border-b border-brand focus:outline-none focus:border-b-2 py-xs text-md text-abbey bg-transparent"
      ><%= @current["answer_text"] %></textarea>
    </form>
    """
  end

  defp answer_input(%{question: %{"question_type" => "single_choice"}} = assigns) do
    ~H"""
    <form phx-change="save_answer" class="space-y-xs">
      <input type="hidden" name="question_id" value={@question["id"]} />
      <label
        :for={opt <- @question["metadata"]["options"] || []}
        class="flex items-center gap-xs text-sm text-abbey cursor-pointer"
      >
        <input
          type="radio"
          name="answer_text"
          value={opt}
          checked={@current["answer_text"] == opt}
        />
        {opt}
      </label>
    </form>
    """
  end

  defp answer_input(%{question: %{"question_type" => "multi_choice"}} = assigns) do
    ~H"""
    <form phx-change="save_values" class="space-y-xs">
      <input type="hidden" name="question_id" value={@question["id"]} />
      <label
        :for={opt <- @question["metadata"]["options"] || []}
        class="flex items-center gap-xs text-sm text-abbey cursor-pointer"
      >
        <input
          type="checkbox"
          name="answer_values[]"
          value={opt}
          checked={opt in (@current["answer_values"] || [])}
        />
        {opt}
      </label>
    </form>
    """
  end

  defp answer_input(%{question: %{"question_type" => "likert_5"}} = assigns) do
    labels =
      assigns.question["metadata"]["scale_labels"] ||
        ["Strongly disagree", "Disagree", "Neutral", "Agree", "Strongly agree"]

    assigns = assign(assigns, labels: labels)

    ~H"""
    <form phx-change="save_answer" class="flex items-center justify-between gap-xs">
      <input type="hidden" name="question_id" value={@question["id"]} />
      <label
        :for={{label, idx} <- Enum.with_index(@labels)}
        class="flex flex-col items-center gap-xs text-xs text-abbey cursor-pointer flex-1"
      >
        <input
          type="radio"
          name="answer_text"
          value={Integer.to_string(idx + 1)}
          checked={@current["answer_text"] == Integer.to_string(idx + 1)}
        />
        <span>{label}</span>
      </label>
    </form>
    """
  end

  defp answer_input(%{question: %{"question_type" => "dimension_rating"}} = assigns) do
    labels =
      assigns.question["metadata"]["scale_labels"] ||
        ["Never", "Rarely", "Sometimes", "Often", "Always"]

    assigns = assign(assigns, labels: labels)

    ~H"""
    <form phx-change="save_answer" class="flex items-center justify-between gap-xs">
      <input type="hidden" name="question_id" value={@question["id"]} />
      <label
        :for={{label, idx} <- Enum.with_index(@labels)}
        class="flex flex-col items-center gap-xs text-xs text-abbey cursor-pointer flex-1"
      >
        <input
          type="radio"
          name="answer_text"
          value={Integer.to_string(idx + 1)}
          checked={@current["answer_text"] == Integer.to_string(idx + 1)}
        />
        <span>{label}</span>
      </label>
    </form>
    """
  end

  attr :title, :string, required: true
  attr :body, :string, required: true

  defp fallback_card(assigns) do
    ~H"""
    <div class="container-sm bg-white rounded-card shadow-card p-lg text-center space-y-sm">
      <h1 class="text-display-sm text-abbey">{@title}</h1>
      <p class="text-sm text-azure">{@body}</p>
    </div>
    """
  end

  defp answered_count(map, questions) do
    Enum.count(questions, &answered?(map, &1["id"]))
  end

  defp current_answer(_map, nil), do: %{"answer_text" => nil, "answer_values" => []}

  defp current_answer(map, q),
    do: Map.get(map, q["id"], %{"answer_text" => nil, "answer_values" => []})
end
