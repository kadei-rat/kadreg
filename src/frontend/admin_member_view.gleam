import frontend/shared_helpers
import gleam/int
import gleam/option.{None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/members.{type MemberRecord}
import models/role

pub fn view(member: MemberRecord) -> Element(t) {
  let telegram_id_str = int.to_string(member.telegram_id)
  let username_display = case member.username {
    Some(u) -> "@" <> u
    None -> "(not set)"
  }

  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.div([attribute.class("page-title-with-back")], [
          html.a(
            [
              attribute.href("/admin/members"),
              attribute.class("back-button"),
            ],
            [html.text("← Back to Members")],
          ),
          html.h1([attribute.class("card-title")], [
            html.text("Member: " <> member.first_name),
          ]),
        ]),
        html.div([attribute.class("member-actions")], [
          html.a(
            [
              attribute.href("/admin/members/" <> telegram_id_str <> "/edit"),
              attribute.class("button"),
            ],
            [html.text("Edit Member")],
          ),
          html.button(
            [
              attribute.class("button button-danger"),
              attribute.attribute(
                "onclick",
                "confirmDelete('" <> telegram_id_str <> "')",
              ),
            ],
            [html.text("Delete Member")],
          ),
        ]),
      ]),
    ]),
    html.div([attribute.class("card")], [
      html.div([attribute.class("member-details-grid")], [
        detail_section("Telegram Account", [
          detail_item("Name", member.first_name),
          detail_item("Username", username_display),
          detail_item("Telegram ID", telegram_id_str),
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
