import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/members.{type MemberRecord}
import models/role

pub fn dashboard_edit_page(
  member: MemberRecord,
  error: Option(String),
) -> Element(t) {
  let telegram_id_str = int.to_string(member.telegram_id)
  let username_display = case member.username {
    Some(u) -> "@" <> u
    None -> "(not set)"
  }

  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.div([attribute.class("page-title-with-back")], [
          html.h1([attribute.class("card-title")], [
            html.text("Edit Your Membership"),
          ]),
        ]),
      ]),
      case error {
        Some(err_msg) ->
          html.div([attribute.class("error-banner")], [html.text(err_msg)])
        None -> html.text("")
      },
      html.form(
        [
          attribute.method("post"),
          attribute.action("/members/" <> telegram_id_str),
          attribute.class("member-edit-form"),
        ],
        [
          html.div([attribute.class("form-sections")], [
            form_section("Telegram Account (read-only)", [
              html.div([attribute.class("readonly-info")], [
                html.p([], [
                  html.strong([], [html.text("Name: ")]),
                  html.text(member.first_name),
                ]),
                html.p([], [
                  html.strong([], [html.text("Username: ")]),
                  html.text(username_display),
                ]),
                html.p([], [
                  html.strong([], [html.text("Telegram ID: ")]),
                  html.text(telegram_id_str),
                ]),
                html.p([], [
                  html.strong([], [html.text("Role: ")]),
                  html.text(role.to_string(member.role)),
                ]),
              ]),
              html.div([attribute.class("form-help")], [
                html.p([], [
                  html.text(
                    "Your name and username are synced from Telegram each time you log in.",
                  ),
                ]),
              ]),
            ]),
            form_section("Emergency Contact", [
              html.div([attribute.class("form-group")], [
                html.label([attribute.for("emergency_contact")], [
                  html.text("Emergency Contact"),
                ]),
                html.textarea(
                  [
                    attribute.id("emergency_contact"),
                    attribute.name("emergency_contact"),
                    attribute.class("form-input"),
                    attribute.placeholder(
                      "@foobar on telegram (relationship: owner)",
                    ),
                  ],
                  member.emergency_contact |> option.unwrap(""),
                ),
              ]),
              html.div([attribute.class("form-help")], [
                html.p([], [
                  html.text(
                    "Whoever you'd like us to contact in an emergency (phone number or tg handle, and their relation to you)",
                  ),
                ]),
              ]),
            ]),
          ]),
          html.div([attribute.class("form-actions-admin")], [
            html.a(
              [attribute.href("/"), attribute.class("button button-secondary")],
              [html.text("Cancel")],
            ),
            html.input([
              attribute.type_("submit"),
              attribute.value("Save Changes"),
              attribute.class("button"),
            ]),
          ]),
        ],
      ),
    ]),
  ])
}

fn form_section(title: String, fields: List(Element(t))) -> Element(t) {
  html.div([attribute.class("form-section")], [
    html.h3([attribute.class("form-section-title")], [html.text(title)]),
    html.div([attribute.class("form-fields")], fields),
  ])
}
