import frontend/shared_helpers
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/members.{type MemberRecord}
import models/membership_id
import models/role

pub fn view(members: List(MemberRecord)) -> Element(t) {
  html.div([], [
    // Page header
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.h1([attribute.class("card-title")], [html.text("Members")]),
      ]),

      // Search and filters (placeholder for now)
      html.div([attribute.class("members-filters")], [
        html.input([
          attribute.type_("search"),
          attribute.placeholder("Search members..."),
          attribute.class("form-input"),
          attribute.id("member-search"),
        ]),
      ]),
      members_table(members),
    ]),
  ])
}

fn members_table(members: List(MemberRecord)) -> Element(t) {
  case members {
    [] ->
      html.div([attribute.class("empty-state")], [
        html.p([], [html.text("No members found.")]),
      ])
    _ ->
      html.table([attribute.class("table"), attribute.id("members-table")], [
        html.thead([], [
          html.tr([], [
            html.th([attribute.class("sortable")], [html.text("ID")]),
            html.th([attribute.class("sortable")], [html.text("Handle")]),
            html.th([attribute.class("sortable")], [html.text("Email")]),
            html.th([attribute.class("sortable")], [html.text("Role")]),
            html.th([attribute.class("sortable")], [html.text("Joined")]),
            html.th([], [html.text("Actions")]),
          ]),
        ]),
        html.tbody([], list.map(members, member_row)),
      ])
  }
}

fn member_row(member: MemberRecord) -> Element(t) {
  let member_id_str = membership_id.to_string(member.membership_id)

  html.tr([], [
    html.td([], [html.text(member_id_str)]),
    html.td([], [html.text(member.handle)]),
    html.td([], [html.text(member.email_address)]),
    html.td([], [
      html.span(
        [attribute.class("role-badge role-" <> role.to_string(member.role))],
        [html.text(role.to_string(member.role))],
      ),
    ]),
    html.td([attribute.class("date-cell")], [
      shared_helpers.format_date_element(member.created_at),
    ]),
    html.td([attribute.class("actions-cell")], [
      html.div([attribute.class("action-buttons")], [
        html.a(
          [
            attribute.href("/admin/members/" <> member_id_str),
            attribute.class("action-button action-view"),
            attribute.title("View member details"),
          ],
          [html.text("View")],
        ),
        html.a(
          [
            attribute.href("/admin/members/" <> member_id_str <> "/edit"),
            attribute.class("action-button action-edit"),
            attribute.title("Edit member"),
          ],
          [html.text("Edit")],
        ),
      ]),
    ]),
  ])
}
