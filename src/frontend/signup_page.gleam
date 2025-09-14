import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn root(error: Option(String)) -> Element(t) {
  html.div([attribute.class("login-container")], [
    html.h1([attribute.class("login-title")], [html.text("Sign Up")]),
    case error {
      Some(err_msg) ->
        html.div([attribute.class("error-banner")], [html.text(err_msg)])
      None -> html.div([], [])
    },
    html.form(
      [
        attribute.method("post"),
        attribute.action("/members"),
        attribute.class("login-form"),
      ],
      [
        html.div([attribute.class("form-group")], [
          html.label([attribute.for("email")], [html.text("Email:")]),
          html.input([
            attribute.type_("email"),
            attribute.id("email"),
            attribute.name("email_address"),
            attribute.required(True),
            attribute.class("form-input"),
          ]),
          html.div([attribute.class("email-invalid")], [
            html.text("Email address invalid"),
          ]),
        ]),
        html.div([attribute.class("form-group")], [
          html.label([attribute.for("legal_name")], [html.text("Legal Name:")]),
          html.input([
            attribute.type_("text"),
            attribute.id("legal_name"),
            attribute.name("legal_name"),
            attribute.required(True),
            attribute.class("form-input"),
          ]),
        ]),
        html.div([attribute.class("form-group")], [
          html.label([attribute.for("handle")], [
            html.text("Handle:"),
          ]),
          html.input([
            attribute.type_("text"),
            attribute.id("handle"),
            attribute.name("handle"),
            attribute.required(True),
            attribute.class("form-input"),
          ]),
        ]),
        html.div([attribute.class("form-group")], [
          html.label([attribute.for("date_of_birth")], [
            html.text("Date of Birth:"),
          ]),
          html.input([
            attribute.type_("date"),
            attribute.id("date_of_birth"),
            attribute.name("date_of_birth"),
            attribute.required(True),
            attribute.class("form-input"),
          ]),
        ]),
        html.div([attribute.class("form-group")], [
          html.label([attribute.for("phone_number")], [
            html.text("Phone Number:"),
          ]),
          html.input([
            attribute.type_("tel"),
            attribute.id("phone_number"),
            attribute.name("phone_number"),
            attribute.required(True),
            attribute.class("form-input"),
          ]),
        ]),
        html.div([attribute.class("form-group")], [
          html.label([attribute.for("postal_address")], [html.text("Address:")]),
          html.textarea(
            [
              attribute.id("postal_address"),
              attribute.name("postal_address"),
              attribute.required(True),
              attribute.class("form-input"),
              attribute.attribute("rows", "3"),
            ],
            "",
          ),
        ]),
        html.div([attribute.class("form-group")], [
          html.label([attribute.for("password")], [html.text("Password:")]),
          html.input([
            attribute.type_("password"),
            attribute.id("password"),
            attribute.name("password"),
            attribute.required(True),
            attribute.class("form-input"),
          ]),
        ]),
        html.div([attribute.class("form-actions")], [
          html.input([
            attribute.type_("submit"),
            attribute.value("Sign Up"),
            attribute.class("login-button"),
          ]),
          html.a([attribute.href("/"), attribute.class("signup-link")], [
            html.text("Already have an account? Login"),
          ]),
        ]),
      ],
    ),
  ])
}
