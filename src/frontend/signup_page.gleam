import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(error: Option(String)) -> Element(t) {
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
