import frontend/shared_helpers.{type NavItem, NavItem}
import gleam/list
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(
  elements: List(Element(t)),
  current_path: String,
) -> List(Element(t)) {
  let nav = build_admin_nav("Admin Dashboard", current_path)
  [nav, html.main([attribute.class("dashboard-main")], elements)]
}

fn build_admin_nav(brand_text: String, current_path: String) -> Element(t) {
  let nav_items = build_admin_nav_items(current_path)

  html.nav([attribute.class("dashboard-nav")], [
    html.div([attribute.class("dashboard-nav-container")], [
      html.div([attribute.class("dashboard-nav-brand")], [html.text(brand_text)]),
      html.ul(
        [attribute.class("dashboard-nav-links")],
        nav_items
          |> list.map(shared_helpers.render_nav_item)
          |> list.append([shared_helpers.logout_link()]),
      ),
    ]),
  ])
}

fn build_admin_nav_items(current_path: String) -> List(NavItem) {
  [
    NavItem("Stats", "/admin", current_path == "/admin"),
    NavItem(
      "Members",
      "/admin/members",
      string.starts_with(current_path, "/admin/members"),
    ),
    NavItem(
      "Registrations",
      "/admin/registrations",
      string.starts_with(current_path, "/admin/registrations"),
    ),
    NavItem(
      "Audit Log",
      "/admin/audit",
      string.starts_with(current_path, "/admin/audit"),
    ),
    NavItem("Back to my membership", "/", current_path == "/"),
  ]
}
