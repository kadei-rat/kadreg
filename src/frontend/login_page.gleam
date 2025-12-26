import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(
  bot_username: String,
  error: Option(String),
  success: Option(String),
) -> Element(t) {
  html.div([attribute.class("login-container")], [
    html.h1([attribute.class("login-title")], [html.text("Login")]),
    case error {
      Some(err_msg) ->
        html.div([attribute.class("error-banner")], [html.text(err_msg)])
      None -> html.text("")
    },
    case success {
      Some(success_msg) ->
        html.div([attribute.class("success-banner")], [html.text(success_msg)])
      None -> html.text("")
    },
    html.div([attribute.class("telegram-login-wrapper")], [
      html.p([attribute.class("login-instructions")], [
        html.text(
          "Click the button below to log in with your Telegram account:",
        ),
      ]),
      telegram_login_widget(bot_username),
    ]),
  ])
}

fn telegram_login_widget(bot_username: String) -> Element(t) {
  html.script(
    [
      attribute.attribute("async", ""),
      attribute.src("https://telegram.org/js/telegram-widget.js?22"),
      attribute.attribute("data-telegram-login", bot_username),
      attribute.attribute("data-size", "large"),
      attribute.attribute("data-auth-url", "/auth/telegram_callback"),
      attribute.attribute("data-request-access", "write"),
    ],
    "",
  )
}
