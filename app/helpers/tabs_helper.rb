# frozen_string_literal: true

module TabsHelper
  def effort_view_tabs(view_object)
    if !view_object.simple? || current_user&.authorized_to_edit?(view_object.effort)
      items = [{ name: "Split times",
                 link: effort_path(view_object.effort),
                 active: action_name == "show" },
               { name: "Projections",
                 link: projections_effort_path(view_object.effort),
                 active: action_name == "projections",
                 hidden: view_object.simple? || !view_object.in_progress? },
               { name: "Analyze times",
                 link: analyze_effort_path(view_object.effort),
                 active: action_name == "analyze",
                 hidden: view_object.simple? || view_object.not_analyzable? },
               { name: "Places + peers",
                 link: place_effort_path(view_object.effort),
                 active: action_name == "place",
                 hidden: view_object.simple? || view_object.not_analyzable? },
               { name: "Audit",
                 link: audit_effort_path(view_object.effort),
                 active: action_name == "audit",
                 hidden: !current_user&.authorized_to_edit?(view_object.effort) }]

      build_view_tabs(items)
    end
  end

  def course_view_tabs(view_object)
    items = [
      { name: "Splits",
        link: course_path(view_object.course, display_style: "splits"),
        active: action_name == "show" && view_object.display_style == "splits" },
      { name: "Events",
        link: course_path(view_object.course, display_style: "events"),
        active: action_name == "show" && view_object.display_style == "events" },
      { name: "All-time best",
        link: best_efforts_course_path(view_object.course),
        active: action_name == "best_efforts" },
      { name: "Plan my effort",
        link: plan_effort_course_path(view_object.course),
        active: action_name == "plan_effort",
        hidden: view_object.simple? },
      { name: "Cutoff analysis",
        link: cutoff_analysis_course_path(view_object.course),
        active: action_name == "cutoff_analysis",
        hidden: view_object.simple? },
    ]

    build_view_tabs(items)
  end

  def setup_view_tabs(presenter)
    items = [
      { name: "Events",
        link: setup_event_group_path(presenter.event_group, display_style: "events"),
        active: action_name == "setup" && presenter.display_style == "events" },
      { name: "Entrants",
        link: setup_event_group_path(presenter.event_group, display_style: "entrants"),
        active: action_name == "setup" && presenter.display_style == "entrants" },
      { name: "Partners",
        link: setup_event_group_path(presenter.event_group, display_style: "partners"),
        active: action_name == "setup" && presenter.display_style == "partners" },
    ]

    build_view_tabs(items)
  end

  private

  def build_view_tabs(items)
    content_tag(:ul, class: "nav nav-tabs nav-tabs-ost") do
      items.each do |item|
        next if item[:hidden]

        active_class = item[:active] ? "active" : nil

        list_item = content_tag(:li, class: ["nav-item", active_class].compact.join(" ")) do
          item[:active] ? content_tag(:a, item[:name]) : link_to(item[:name], item[:link])
        end

        concat(list_item)
      end
    end
  end
end
