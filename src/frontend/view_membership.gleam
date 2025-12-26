import frontend/shared_helpers
import gleam/int
import gleam/option
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/members.{type MemberRecord}
import models/role

pub fn view(member: MemberRecord) -> Element(t) {
  let username_display = case member.username {
    option.Some(u) -> "@" <> u
    option.None -> "(not set)"
  }

  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.h2([attribute.class("card-title")], [
          html.text("Your Membership Details"),
        ]),
      ]),
      html.div([attribute.class("member-details-grid")], [
        detail_section("Telegram Account", [
          detail_item("Name", member.first_name),
          detail_item("Username", username_display),
          detail_item("Telegram ID", int.to_string(member.telegram_id)),
        ]),
        detail_section("Membership Information", [
          detail_item("Role", role.to_string(member.role)),
          detail_item(
            "Emergency Contact",
            member.emergency_contact |> option.unwrap("(not set)"),
          ),
        ]),
        detail_section("Account Information", [
          detail_item(
            "Member Since",
            shared_helpers.format_date(member.created_at),
          ),
          detail_item(
            "Last Updated",
            shared_helpers.format_date(member.updated_at),
          ),
        ]),
      ]),
    ]),
  ])
}

fn detail_section(title: String, items: List(Element(t))) -> Element(t) {
  html.div([attribute.class("detail-section")], [
    html.h3([attribute.class("detail-section-title")], [html.text(title)]),
    html.div([attribute.class("detail-items")], items),
  ])
}

fn detail_item(label: String, value: String) -> Element(t) {
  html.div([attribute.class("detail-item")], [
    html.dt([attribute.class("detail-label")], [html.text(label)]),
    html.dd([attribute.class("detail-value")], [html.text(value)]),
  ])
}
