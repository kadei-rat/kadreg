import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/conventions.{type Convention}
import models/registrations.{
  type Registration, type RegistrationStatus, type RegistrationTier,
}

pub fn view(
  convention: Convention,
  registration: Registration,
  display_name: String,
  error: Option(String),
) -> Element(t) {
  let telegram_id_str = int.to_string(registration.member_id)

  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.div([attribute.class("page-title-with-back")], [
          html.a(
            [
              attribute.href("/admin/registrations"),
              attribute.class("back-button"),
            ],
            [html.text("← Back to Registrations")],
          ),
          html.h1([attribute.class("card-title")], [
            html.text("Edit Registration: " <> display_name),
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
          attribute.action("/admin/registrations/" <> telegram_id_str),
          attribute.class("member-edit-form"),
        ],
        [
          html.div([attribute.class("form-sections")], [
            form_section("Registration Details", [
              html.div([attribute.class("readonly-info")], [
                html.p([], [
                  html.strong([], [html.text("Member: ")]),
                  html.text(display_name),
                ]),
                html.p([], [
                  html.strong([], [html.text("Telegram ID: ")]),
                  html.text(telegram_id_str),
                ]),
                html.p([], [
                  html.strong([], [html.text("Convention: ")]),
                  html.text(convention.name),
                ]),
                html.p([], [
                  html.strong([], [html.text("Registered: ")]),
                  html.text(registration.created_at),
                ]),
              ]),
              tier_field(convention, registration.tier),
              status_field(registration.status),
            ]),
          ]),
          html.div([attribute.class("form-actions-admin")], [
            html.a(
              [
                attribute.href("/admin/registrations"),
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

fn tier_field(
  convention: Convention,
  current_tier: RegistrationTier,
) -> Element(t) {
  html.div([attribute.class("form-group")], [
    html.label([attribute.for("tier")], [html.text("Tier")]),
    html.select(
      [
        attribute.id("tier"),
        attribute.name("tier"),
        attribute.class("form-input"),
      ],
      [
        tier_option(
          registrations.Standard,
          "Standard",
          convention.prices.standard,
          current_tier,
        ),
        tier_option(
          registrations.Sponsor,
          "Sponsor",
          convention.prices.sponsor,
          current_tier,
        ),
        tier_option(
          registrations.Subsidised,
          "Subsidised",
          convention.prices.subsidised,
          current_tier,
        ),
        tier_option(
          registrations.DoubleSubsidised,
          "Double Subsidised",
          convention.prices.double_subsidised,
          current_tier,
        ),
      ],
    ),
  ])
}

fn tier_option(
  tier: RegistrationTier,
  label: String,
  price: Int,
  current_tier: RegistrationTier,
) -> Element(t) {
  let tier_str = registrations.tier_to_string(tier)
  let display = label <> " (£" <> int.to_string(price) <> ")"
  let option_attrs = case tier == current_tier {
    True -> [attribute.value(tier_str), attribute.selected(True)]
    False -> [attribute.value(tier_str)]
  }

  html.option(option_attrs, display)
}

fn status_field(current_status: RegistrationStatus) -> Element(t) {
  html.div([attribute.class("form-group")], [
    html.label([attribute.for("status")], [html.text("Status")]),
    html.select(
      [
        attribute.id("status"),
        attribute.name("status"),
        attribute.class("form-input"),
      ],
      [
        status_option(registrations.Pending, current_status),
        status_option(registrations.Successful, current_status),
        status_option(registrations.Paid, current_status),
        status_option(registrations.Cancelled, current_status),
      ],
    ),
  ])
}

fn status_option(
  status: RegistrationStatus,
  current_status: RegistrationStatus,
) -> Element(t) {
  let status_str = registrations.status_to_string(status)
  let display = registrations.status_to_display_string(status)
  let option_attrs = case status == current_status {
    True -> [attribute.value(status_str), attribute.selected(True)]
    False -> [attribute.value(status_str)]
  }

  html.option(option_attrs, display)
}
