import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/members.{type MemberRecord}
import models/membership_id

pub fn dashboard_edit_page(
  member: MemberRecord,
  error: Option(String),
) -> Element(t) {
  let member_id_str = membership_id.to_string(member.membership_id)

  html.div([], [
    // Page header
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.div([attribute.class("page-title-with-back")], [
          html.h1([attribute.class("card-title")], [
            html.text("Edit Your Membership"),
          ]),
        ]),
      ]),

      // Error banner
      case error {
        Some(err_msg) ->
          html.div([attribute.class("error-banner")], [html.text(err_msg)])
        None -> html.div([], [])
      },
    ]),

    // Edit form
    html.div([attribute.class("card")], [
      html.form(
        [
          attribute.method("post"),
          attribute.action("/members/" <> member_id_str),
          attribute.class("member-edit-form"),
        ],
        [
          html.div([attribute.class("form-sections")], [
            // Basic information section
            form_section("Basic Information", [
              form_field(
                "Legal Name",
                "legal_name",
                "text",
                member.legal_name,
                True,
              ),
              form_field("Handle", "handle", "text", member.handle, True),
              form_field(
                "Email Address",
                "email_address",
                "email",
                member.email_address,
                True,
              ),
            ]),

            // Contact information section
            form_section("Contact Information", [
              form_field(
                "Phone Number",
                "phone_number",
                "tel",
                member.phone_number,
                True,
              ),
              textarea_field(
                "Address",
                "postal_address",
                member.postal_address,
                True,
              ),
            ]),

            // Password section
            form_section("Password", [
              form_field(
                "Current Password",
                "current_password",
                "password",
                "",
                True,
              ),
              form_field("New Password", "new_password", "password", "", False),
              html.div([attribute.class("form-help")], [
                html.p([], [
                  html.text(
                    "Leave new password blank to keep your current password.",
                  ),
                ]),
              ]),
            ]),

            // Account status section
            form_section("Account Information", [
              html.div([attribute.class("readonly-info")], [
                html.p([], [
                  html.strong([], [html.text("Membership ID: ")]),
                  html.text(member_id_str),
                ]),
                html.p([], [
                  html.strong([], [html.text("Role: ")]),
                  html.text("Member"),
                ]),
                html.p([], [
                  html.strong([], [html.text("Member Since: ")]),
                  html.text(member.created_at),
                ]),
              ]),
            ]),
          ]),

          // Form actions
          html.div([attribute.class("form-actions-admin")], [
            html.a(
              [
                attribute.href("/dashboard"),
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
    html.textarea(textarea_attrs, value),
  ])
}
