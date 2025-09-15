import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub type NavItem {
  NavItem(text: String, href: String, is_active: Bool)
}

pub fn render_nav_item(item: NavItem) -> Element(t) {
  let link_class = case item.is_active {
    True -> "dashboard-nav-link dashboard-nav-link-active"
    False -> "dashboard-nav-link"
  }

  html.li([attribute.class("dashboard-nav-item")], [
    html.a([attribute.href(item.href), attribute.class(link_class)], [
      html.text(item.text),
    ]),
  ])
}

pub fn logout_link() -> Element(t) {
  html.li([attribute.class("dashboard-nav-item")], [
    html.form([attribute.method("POST"), attribute.action("/auth/logout")], [
      html.button(
        [
          attribute.type_("submit"),
          attribute.class("dashboard-nav-link dashboard-nav-logout"),
        ],
        [html.text("Logout")],
      ),
    ]),
  ])
}

pub fn format_date(date_str: String) -> String {
  case date_str {
    "" -> "—"
    _ -> date_str
  }
}

pub fn format_date_element(date_str: String) -> Element(t) {
  html.text(format_date(date_str))
}
