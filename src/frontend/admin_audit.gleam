import frontend/shared_helpers
import gleam/int
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/admin_audit.{type AuditLogEntry}

pub fn view(audit_entries: List(AuditLogEntry)) -> Element(t) {
  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.h1([attribute.class("card-title")], [html.text("Audit Log")]),
      ]),
      audit_table(audit_entries),
    ]),
  ])
}

fn audit_table(entries: List(AuditLogEntry)) -> Element(t) {
  case entries {
    [] ->
      html.div([attribute.class("empty-state")], [
        html.p([], [html.text("No audit entries found.")]),
      ])
    _ ->
      html.table([attribute.class("table"), attribute.id("audit-table")], [
        html.thead([], [
          html.tr([], [
            html.th([], [html.text("Time")]),
            html.th([], [html.text("Admin")]),
            html.th([], [html.text("Action")]),
            html.th([], [html.text("Target Member")]),
            html.th([], [html.text("Changes")]),
          ]),
        ]),
        html.tbody([], list.map(entries, audit_row)),
      ])
  }
}

fn audit_row(entry: AuditLogEntry) -> Element(t) {
  let performed_by_str = int.to_string(entry.performed_by)
  let target_member_str = int.to_string(entry.target_member)

  let action_text = case entry.action_type {
    admin_audit.UpdateMember -> "Updated member"
    admin_audit.DeleteMember -> "Deleted member"
  }

  html.tr([], [
    html.td([attribute.class("date-cell")], [
      shared_helpers.format_date_element(entry.performed_at),
    ]),
    html.td([], [
      html.a([attribute.href("/admin/members/" <> performed_by_str)], [
        html.text(performed_by_str),
      ]),
    ]),
    html.td([], [html.text(action_text)]),
    html.td([], [
      html.a([attribute.href("/admin/members/" <> target_member_str)], [
        html.text(target_member_str),
      ]),
    ]),
    html.td([attribute.class("changes-cell")], [
      html.details([], [
        html.summary([], [html.text("View changes")]),
        html.div([attribute.class("json-diff")], [
          html.div([], [
            html.strong([], [html.text("Before:")]),
            html.pre([], [html.text(entry.old_values)]),
          ]),
          html.div([], [
            html.strong([], [html.text("After:")]),
            html.pre([], [html.text(entry.new_values)]),
          ]),
        ]),
      ]),
    ]),
  ])
}
