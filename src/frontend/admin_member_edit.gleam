import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/members.{type MemberRecord}
import models/role.{type Role}

pub fn member_edit_page(
  member: MemberRecord,
  error: Option(String),
) -> Element(t) {
  let telegram_id_str = int.to_string(member.telegram_id)

  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.div([attribute.class("page-title-with-back")], [
          html.a(
            [
              attribute.href("/admin/members/" <> telegram_id_str),
              attribute.class("back-button"),
            ],
            [html.text("← Back to Member")],
          ),
          html.h1([attribute.class("card-title")], [
            html.text("Edit: " <> member.first_name),
          ]),
        ]),
      ]),
      case error {
        Some(err_msg) ->
          html.div([attribute.class("error-banner")], [html.text(err_msg)])
        None -> html.text("")
      },
    ]),
    html.div([attribute.class("card")], [
      html.form(
        [
          attribute.method("post"),
          attribute.action("/admin/members/" <> telegram_id_str),
          attribute.class("member-edit-form"),
        ],
        [
          html.div([attribute.class("form-sections")], [
            form_section("Telegram Information", [
              form_field("Name", "first_name", "text", member.first_name, True),
              form_field(
                "Username",
                "username",
                "text",
                member.username |> option.unwrap(""),
                False,
              ),
              html.div([attribute.class("readonly-info")], [
                html.p([], [
                  html.strong([], [html.text("Telegram ID: ")]),
                  html.text(telegram_id_str),
                ]),
              ]),
              html.div([attribute.class("form-help")], [
                html.p([], [
                  html.text(
                    "Note: Name and username are normally synced from Telegram on login.",
                  ),
                ]),
              ]),
            ]),
            form_section("Membership Information", [
              textarea_field(
                "Emergency Contact",
                "emergency_contact",
                member.emergency_contact |> option.unwrap(""),
                False,
                "Whoever they'd like us to contact in an emergency (phone number or tg handle, and their relation)",
              ),
              role_field("Role", member.role),
            ]),
            form_section("Account Information", [
              html.div([attribute.class("readonly-info")], [
                html.p([], [
                  html.strong([], [html.text("Member Since: ")]),
                  html.text(member.created_at),
                ]),
                html.p([], [
                  html.strong([], [html.text("Last Updated: ")]),
                  html.text(member.updated_at),
                ]),
              ]),
            ]),
          ]),
          html.div([attribute.class("form-actions-admin")], [
            html.a(
              [
                attribute.href("/admin/members/" <> telegram_id_str),
                attribute.class("button button-secondary"),
              ],
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

fn form_field(
  label: String,
  name: String,
  field_type: String,
  value: String,
  required: Bool,
) -> Element(t) {
  let input_attrs = case required {
    True -> [
      attribute.type_(field_type),
      attribute.id(name),
      attribute.name(name),
      attribute.value(value),
      attribute.class("form-input"),
      attribute.required(True),
    ]
    False -> [
      attribute.type_(field_type),
      attribute.id(name),
      attribute.name(name),
      attribute.value(value),
      attribute.class("form-input"),
    ]
  }

  html.div([attribute.class("form-group")], [
    html.label([attribute.for(name)], [html.text(label)]),
    html.input(input_attrs),
  ])
}

fn textarea_field(
  label: String,
  name: String,
  value: String,
  required: Bool,
  help_text: String,
) -> Element(t) {
  let textarea_attrs = case required {
    True -> [
      attribute.id(name),
      attribute.name(name),
      attribute.class("form-input"),
      attribute.attribute("rows", "3"),
      attribute.required(True),
    ]
    False -> [
      attribute.id(name),
      attribute.name(name),
      attribute.class("form-input"),
      attribute.attribute("rows", "3"),
    ]
  }

  html.div([attribute.class("form-group")], [
    html.label([attribute.for(name)], [html.text(label)]),
    html.div([attribute.class("form-help")], [
      html.p([], [html.text(help_text)]),
    ]),
    html.textarea(textarea_attrs, value),
  ])
}

fn role_field(label: String, current_role: Role) -> Element(t) {
  html.div([attribute.class("form-group")], [
    html.label([attribute.for("role")], [html.text(label)]),
    html.select(
      [
        attribute.id("role"),
        attribute.name("role"),
        attribute.class("form-input"),
      ],
      [
        role_option(role.Member, current_role),
        role_option(role.Staff, current_role),
        role_option(role.RegStaff, current_role),
        role_option(role.Director, current_role),
        role_option(role.Sysadmin, current_role),
      ],
    ),
  ])
}

fn role_option(option_role: Role, current_role: Role) -> Element(t) {
  let role_str = role.to_string(option_role)
  let option_attrs = case option_role == current_role {
    True -> [attribute.value(role_str), attribute.selected(True)]
    False -> [attribute.value(role_str)]
  }

  html.option(option_attrs, role_str)
}
