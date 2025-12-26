import frontend/shared_helpers
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/members.{type MemberRecord}
import models/registrations.{type RegistrationStatus}
import models/role

pub fn view(
  members: List(MemberRecord),
  reg_statuses: Dict(Int, RegistrationStatus),
) -> Element(t) {
  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.h1([attribute.class("card-title")], [html.text("Members")]),
      ]),
      html.div([attribute.class("members-filters")], [
        html.input([
          attribute.type_("search"),
          attribute.placeholder("Search members..."),
          attribute.class("form-input"),
          attribute.id("member-search"),
        ]),
      ]),
      members_table(members, reg_statuses),
    ]),
  ])
}

fn members_table(
  members: List(MemberRecord),
  reg_statuses: Dict(Int, RegistrationStatus),
) -> Element(t) {
  case members {
    [] ->
      html.div([attribute.class("empty-state")], [
        html.p([], [html.text("No members found.")]),
      ])
    _ ->
      html.table([attribute.class("table"), attribute.id("members-table")], [
        html.thead([], [
          html.tr([], [
            html.th([attribute.class("sortable")], [html.text("Name")]),
            html.th([attribute.class("sortable")], [html.text("Username")]),
            html.th([attribute.class("sortable")], [html.text("Role")]),
            html.th([attribute.class("sortable")], [html.text("Reg Status")]),
            html.th([attribute.class("sortable")], [html.text("Joined")]),
            html.th([], [html.text("Actions")]),
          ]),
        ]),
        html.tbody([], list.map(members, fn(m) { member_row(m, reg_statuses) })),
      ])
  }
}

fn member_row(
  member: MemberRecord,
  reg_statuses: Dict(Int, RegistrationStatus),
) -> Element(t) {
  let telegram_id_str = int.to_string(member.telegram_id)
  let username_display = case member.username {
    Some(u) -> "@" <> u
    None -> "-"
  }

  let reg_status_cell = case dict.get(reg_statuses, member.telegram_id) {
    Ok(status) -> {
      let status_class =
        "status-badge status-" <> registrations.status_to_string(status)
      html.span([attribute.class(status_class)], [
        html.text(registrations.status_to_display_string(status)),
      ])
    }
    Error(_) -> html.text("-")
  }

  html.tr([], [
    html.td([], [html.text(member.first_name)]),
    html.td([], [html.text(username_display)]),
    html.td([], [
      html.span(
        [attribute.class("role-badge role-" <> role.to_string(member.role))],
        [html.text(role.to_string(member.role))],
      ),
    ]),
    html.td([], [reg_status_cell]),
    html.td([attribute.class("date-cell")], [
      shared_helpers.format_date_element(member.created_at),
    ]),
    html.td([attribute.class("actions-cell")], [
      html.div([attribute.class("action-buttons")], [
        html.a(
          [
            attribute.href("/admin/members/" <> telegram_id_str),
            attribute.class("action-button action-view"),
            attribute.title("View member details"),
          ],
          [html.text("View")],
        ),
        html.a(
          [
            attribute.href("/admin/members/" <> telegram_id_str <> "/edit"),
            attribute.class("action-button action-edit"),
            attribute.title("Edit member"),
          ],
          [html.text("Edit")],
        ),
      ]),
    ]),
  ])
}
