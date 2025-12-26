import frontend/shared_helpers
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/conventions.{type Convention}
import models/membership_id
import models/registrations.{type RegistrationWithMember}

pub fn view(
  convention: Convention,
  registrations: List(RegistrationWithMember),
) -> Element(t) {
  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.h1([attribute.class("card-title")], [
          html.text("Registrations: " <> convention.name),
        ]),
      ]),
      html.div([attribute.class("members-filters")], [
        html.input([
          attribute.type_("search"),
          attribute.placeholder("Search registrations..."),
          attribute.class("form-input"),
          attribute.id("registration-search"),
        ]),
      ]),
      registrations_table(registrations),
    ]),
  ])
}

fn registrations_table(regs: List(RegistrationWithMember)) -> Element(t) {
  case regs {
    [] ->
      html.div([attribute.class("empty-state")], [
        html.p([], [html.text("No registrations found.")]),
      ])
    _ ->
      html.table(
        [attribute.class("table"), attribute.id("registrations-table")],
        [
          html.thead([], [
            html.tr([], [
              html.th([attribute.class("sortable")], [html.text("ID")]),
              html.th([attribute.class("sortable")], [html.text("Handle")]),
              html.th([attribute.class("sortable")], [html.text("Tier")]),
              html.th([attribute.class("sortable")], [html.text("Status")]),
              html.th([attribute.class("sortable")], [html.text("Registered")]),
              html.th([], [html.text("Actions")]),
            ]),
          ]),
          html.tbody([], list.map(regs, registration_row)),
        ],
      )
  }
}

fn registration_row(reg: RegistrationWithMember) -> Element(t) {
  let member_id_str = membership_id.to_string(reg.membership_id)
  let status_class =
    "status-badge status-" <> registrations.status_to_string(reg.status)
  let tier_class = "tier-badge tier-" <> registrations.tier_to_string(reg.tier)

  html.tr([], [
    html.td([], [html.text(member_id_str)]),
    html.td([], [html.text(reg.handle)]),
    html.td([], [
      html.span([attribute.class(tier_class)], [
        html.text(registrations.tier_to_display_string(reg.tier)),
      ]),
    ]),
    html.td([], [
      html.span([attribute.class(status_class)], [
        html.text(registrations.status_to_display_string(reg.status)),
      ]),
    ]),
    html.td([attribute.class("date-cell")], [
      shared_helpers.format_date_element(reg.created_at),
    ]),
    html.td([attribute.class("actions-cell")], [
      html.div([attribute.class("action-buttons")], [
        html.a(
          [
            attribute.href("/admin/members/" <> member_id_str),
            attribute.class("action-button action-view"),
            attribute.title("View member"),
          ],
          [html.text("View")],
        ),
        html.a(
          [
            attribute.href("/admin/registrations/" <> member_id_str <> "/edit"),
            attribute.class("action-button action-edit"),
            attribute.title("Edit registration"),
          ],
          [html.text("Edit")],
        ),
      ]),
    ]),
  ])
}
