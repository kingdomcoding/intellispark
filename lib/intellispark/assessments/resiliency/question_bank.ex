defmodule Intellispark.Assessments.Resiliency.QuestionBank do
  @moduledoc """
  Canon-defined resiliency question bank for ScholarCentric's six skills
  across three grade bands. Versioned so mid-year question rewrites bump
  the version string stamped on each Assessment row.
  """

  @skills ~w(confidence persistence organization getting_along resilience curiosity)a

  @current_version "v1"

  @questions %{
    {:grades_9_12, "v1"} => [
      %{id: "9_12_c_1", skill: :confidence, prompt: "I believe I can handle hard schoolwork."},
      %{id: "9_12_c_2", skill: :confidence, prompt: "I feel capable when I face a new challenge."},
      %{id: "9_12_c_3", skill: :confidence, prompt: "I can speak up in class when I have something to share."},
      %{id: "9_12_p_1", skill: :persistence, prompt: "When something is hard, I keep trying."},
      %{id: "9_12_p_2", skill: :persistence, prompt: "I finish long assignments even when they feel boring."},
      %{id: "9_12_p_3", skill: :persistence, prompt: "I do not give up when I get stuck."},
      %{id: "9_12_o_1", skill: :organization, prompt: "I write down my homework and assignments."},
      %{id: "9_12_o_2", skill: :organization, prompt: "I keep my school materials in order."},
      %{id: "9_12_o_3", skill: :organization, prompt: "I plan ahead for tests and projects."},
      %{id: "9_12_g_1", skill: :getting_along, prompt: "I work well in a group with classmates."},
      %{id: "9_12_g_2", skill: :getting_along, prompt: "I listen to others' ideas, even when I disagree."},
      %{id: "9_12_g_3", skill: :getting_along, prompt: "I resolve disagreements without fighting."},
      %{id: "9_12_r_1", skill: :resilience, prompt: "I bounce back when things go wrong at school."},
      %{id: "9_12_r_2", skill: :resilience, prompt: "I can handle a bad grade without giving up."},
      %{id: "9_12_r_3", skill: :resilience, prompt: "I stay calm when plans change unexpectedly."},
      %{id: "9_12_u_1", skill: :curiosity, prompt: "I ask questions when I want to learn more."},
      %{id: "9_12_u_2", skill: :curiosity, prompt: "I enjoy exploring new topics on my own."},
      %{id: "9_12_u_3", skill: :curiosity, prompt: "I look for answers when I do not understand something."}
    ],
    {:grades_6_8, "v1"} => [
      %{id: "6_8_c_1", skill: :confidence, prompt: "I believe I am good at schoolwork."},
      %{id: "6_8_c_2", skill: :confidence, prompt: "I feel sure of myself when I try new things."},
      %{id: "6_8_c_3", skill: :confidence, prompt: "I raise my hand in class when I know the answer."},
      %{id: "6_8_p_1", skill: :persistence, prompt: "When schoolwork is hard, I keep going."},
      %{id: "6_8_p_2", skill: :persistence, prompt: "I finish what I start, even when it is not fun."},
      %{id: "6_8_p_3", skill: :persistence, prompt: "I keep trying when I do not get something right the first time."},
      %{id: "6_8_o_1", skill: :organization, prompt: "I keep track of my homework."},
      %{id: "6_8_o_2", skill: :organization, prompt: "I remember to bring the things I need to school."},
      %{id: "6_8_o_3", skill: :organization, prompt: "I know what I am supposed to do each day."},
      %{id: "6_8_g_1", skill: :getting_along, prompt: "I get along well with other kids."},
      %{id: "6_8_g_2", skill: :getting_along, prompt: "I share when I work with a partner."},
      %{id: "6_8_g_3", skill: :getting_along, prompt: "I calm down when someone is mean to me."},
      %{id: "6_8_r_1", skill: :resilience, prompt: "I feel better after a bad day at school."},
      %{id: "6_8_r_2", skill: :resilience, prompt: "I do not stay upset for long when something goes wrong."},
      %{id: "6_8_r_3", skill: :resilience, prompt: "I can keep working even after I make a mistake."},
      %{id: "6_8_u_1", skill: :curiosity, prompt: "I like to learn about new things."},
      %{id: "6_8_u_2", skill: :curiosity, prompt: "I ask a lot of questions."},
      %{id: "6_8_u_3", skill: :curiosity, prompt: "I wonder how things work."}
    ],
    {:grades_3_5, "v1"} => [
      %{id: "3_5_c_1", skill: :confidence, prompt: "I am good at school."},
      %{id: "3_5_c_2", skill: :confidence, prompt: "I try new things."},
      %{id: "3_5_c_3", skill: :confidence, prompt: "I talk in class."},
      %{id: "3_5_p_1", skill: :persistence, prompt: "I try again when something is hard."},
      %{id: "3_5_p_2", skill: :persistence, prompt: "I finish my work."},
      %{id: "3_5_p_3", skill: :persistence, prompt: "I do not give up."},
      %{id: "3_5_o_1", skill: :organization, prompt: "I know what my homework is."},
      %{id: "3_5_o_2", skill: :organization, prompt: "I put my things where they go."},
      %{id: "3_5_o_3", skill: :organization, prompt: "I am ready for school each day."},
      %{id: "3_5_g_1", skill: :getting_along, prompt: "I play well with other kids."},
      %{id: "3_5_g_2", skill: :getting_along, prompt: "I share my things."},
      %{id: "3_5_g_3", skill: :getting_along, prompt: "I use my words when I am mad."},
      %{id: "3_5_r_1", skill: :resilience, prompt: "I feel okay after I cry."},
      %{id: "3_5_r_2", skill: :resilience, prompt: "I can try again after a mistake."},
      %{id: "3_5_r_3", skill: :resilience, prompt: "I keep going when I feel sad."},
      %{id: "3_5_u_1", skill: :curiosity, prompt: "I like learning."},
      %{id: "3_5_u_2", skill: :curiosity, prompt: "I ask questions."},
      %{id: "3_5_u_3", skill: :curiosity, prompt: "I look at new things."}
    ]
  }

  def questions_for(grade_band, version \\ @current_version) do
    Map.fetch!(@questions, {grade_band, version})
  end

  def skills, do: @skills

  def current_version, do: @current_version

  def grade_bands, do: [:grades_3_5, :grades_6_8, :grades_9_12]

  def skill_for_question(grade_band, question_id, version \\ @current_version) do
    grade_band
    |> questions_for(version)
    |> Enum.find(&(&1.id == question_id))
    |> case do
      nil -> nil
      q -> q.skill
    end
  end
end
