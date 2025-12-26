import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/conventions.{type Convention}
import models/registrations.{type Registration}

pub fn view(
  convention: Convention,
  registration: Option(Registration),
  registration_open: Bool,
  error: Option(String),
) -> Element(t) {
  html.div([], [
    html.div([attribute.class("card")], [
      html.div([attribute.class("card-header")], [
        html.h1([attribute.class("card-title")], [
          html.text("Register for " <> convention.name),
        ]),
      ]),
      case error {
        Some(err_msg) ->
          html.div([attribute.class("error-banner")], [html.text(err_msg)])
        None -> html.text("")
      },
      html.div([attribute.class("card-body")], [
        case registration, registration_open {
          // Already registered - show status
          Some(reg), _ -> view_existing_registration(convention, reg)
          // Not registered but registration is open
          None, True -> view_registration_form(convention)
          // Registration closed
          None, False -> view_coming_soon()
        },
      ]),
    ]),
  ])
}

fn view_coming_soon() -> Element(t) {
  html.div([attribute.class("coming-soon")], [
    html.p([attribute.class("coming-soon-text")], [
      html.text("Registration is not yet open. Check back soon!"),
    ]),
  ])
}

fn view_registration_form(convention: Convention) -> Element(t) {
  html.form(
    [
      attribute.method("post"),
      attribute.action("/registrations"),
      attribute.class("registration-form"),
    ],
    [
      html.input([
        attribute.type_("hidden"),
        attribute.name("convention_id"),
        attribute.value(convention.id),
      ]),
      html.div([attribute.class("form-section")], [
        html.h3([attribute.class("form-section-title")], [
          html.text("Select Your Tier"),
        ]),
        html.div([attribute.class("tier-options")], [
          tier_option(
            "standard",
            "Standard",
            convention.prices.standard,
            "Regular registration",
            True,
          ),
          tier_option(
            "sponsor",
            "Sponsor",
            convention.prices.sponsor,
            "Help subsidise someone else's attendance. No extra perks, just if you want to subsidise someone who might not otherwise be able to attend.",
            False,
          ),
          tier_option(
            "subsidised",
            "Subsidised",
            convention.prices.subsidised,
            "For those who would not be able to attend otherwise due to financial constraints. No questions asked.",
            False,
          ),
        ]),
      ]),
      html.div([attribute.class("form-actions")], [
        html.input([
          attribute.type_("submit"),
          attribute.value("Register"),
          attribute.class("button"),
        ]),
      ]),
    ],
  )
}

fn tier_option(
  value: String,
  label: String,
  price: Int,
  description: String,
  checked: Bool,
) -> Element(t) {
  let price_str = "£" <> int.to_string(price)

  html.label([attribute.class("tier-option")], [
    html.input(
      [
        attribute.type_("radio"),
        attribute.name("tier"),
        attribute.value(value),
        attribute.class("tier-radio"),
      ]
      |> add_checked(checked),
    ),
    html.div([attribute.class("tier-content")], [
      html.div([attribute.class("tier-header")], [
        html.span([attribute.class("tier-name")], [html.text(label)]),
        html.span([attribute.class("tier-price")], [html.text(price_str)]),
      ]),
      html.p([attribute.class("tier-description")], [html.text(description)]),
    ]),
  ])
}

fn add_checked(
  attrs: List(attribute.Attribute(t)),
  checked: Bool,
) -> List(attribute.Attribute(t)) {
  case checked {
    True -> [attribute.checked(True), ..attrs]
    False -> attrs
  }
}

fn view_existing_registration(
  convention: Convention,
  reg: Registration,
) -> Element(t) {
  let can_modify = registrations.can_user_modify(reg.status)
  let status_class =
    "status-badge status-" <> registrations.status_to_string(reg.status)

  html.div([attribute.class("existing-registration")], [
    html.div([attribute.class("registration-status-section")], [
      html.h3([], [html.text("Your Registration")]),
      html.div([attribute.class("registration-details")], [
        html.p([], [
          html.strong([], [html.text("Status: ")]),
          html.span([attribute.class(status_class)], [
            html.text(registrations.status_to_display_string(reg.status)),
          ]),
        ]),
        html.p([], [
          html.strong([], [html.text("Tier: ")]),
          html.text(registrations.tier_to_display_string(reg.tier)),
          html.text(
            " (£" <> int.to_string(tier_price(convention, reg.tier)) <> ")",
          ),
        ]),
        html.p([], [
          html.strong([], [html.text("Registered: ")]),
          html.text(reg.created_at),
        ]),
      ]),
    ]),
    case can_modify {
      True -> view_modify_registration(convention, reg)
      False ->
        html.p([attribute.class("registration-locked")], [
          html.text(
            "Your registration is finalised and cannot be modified. Contact staff if you need assistance.",
          ),
        ])
    },
  ])
}

fn view_modify_registration(
  convention: Convention,
  reg: Registration,
) -> Element(t) {
  html.div([attribute.class("modify-registration")], [
    html.h3([], [html.text("Change Tier")]),
    html.form(
      [
        attribute.method("post"),
        attribute.action("/registrations/" <> convention.id),
        attribute.class("registration-form"),
      ],
      [
        html.div([attribute.class("tier-options")], [
          tier_option_selected(
            "standard",
            "Standard",
            convention.prices.standard,
            reg.tier == registrations.Standard,
          ),
          tier_option_selected(
            "sponsor",
            "Sponsor",
            convention.prices.sponsor,
            reg.tier == registrations.Sponsor,
          ),
          tier_option_selected(
            "subsidised",
            "Subsidised",
            convention.prices.subsidised,
            reg.tier == registrations.Subsidised,
          ),
        ]),
        html.div([attribute.class("form-actions")], [
          html.input([
            attribute.type_("submit"),
            attribute.value("Update Tier"),
            attribute.class("button"),
          ]),
        ]),
      ],
    ),
    html.hr([]),
    html.h3([], [html.text("Cancel Registration")]),
    html.p([], [
      html.text(
        "If you can no longer attend, you can cancel your registration below.",
      ),
    ]),
    html.form(
      [
        attribute.method("post"),
        attribute.action("/registrations/" <> convention.id <> "/cancel"),
        attribute.class("cancel-form"),
      ],
      [
        html.input([
          attribute.type_("submit"),
          attribute.value("Cancel Registration"),
          attribute.class("button button-danger"),
        ]),
      ],
    ),
  ])
}

fn tier_option_selected(
  value: String,
  label: String,
  price: Int,
  selected: Bool,
) -> Element(t) {
  let price_str = "£" <> int.to_string(price)

  html.label([attribute.class("tier-option tier-option-compact")], [
    html.input(
      [
        attribute.type_("radio"),
        attribute.name("tier"),
        attribute.value(value),
        attribute.class("tier-radio"),
      ]
      |> add_checked(selected),
    ),
    html.span([attribute.class("tier-name")], [html.text(label)]),
    html.span([attribute.class("tier-price")], [html.text(price_str)]),
  ])
}

fn tier_price(
  convention: Convention,
  tier: registrations.RegistrationTier,
) -> Int {
  case tier {
    registrations.Standard -> convention.prices.standard
    registrations.Sponsor -> convention.prices.sponsor
    registrations.Subsidised -> convention.prices.subsidised
    registrations.DoubleSubsidised -> convention.prices.double_subsidised
  }
}
