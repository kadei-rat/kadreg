import frontend/shared_helpers.{type NavItem, NavItem}
import gleam/list
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(
  elements: List(Element(t)),
  current_path: String,
  can_access_admin: Bool,
) -> List(Element(t)) {
  let nav = build_user_nav("Dashboard", current_path, can_access_admin)
  [nav, html.main([attribute.class("dashboard-main")], elements)]
}

fn build_user_nav(
  brand_text: String,
  current_path: String,
  can_access_admin: Bool,
) -> Element(t) {
  let nav_items = build_user_nav_items(current_path, can_access_admin)

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

fn build_user_nav_items(
  current_path: String,
  can_access_admin: Bool,
) -> List(NavItem) {
  let base_items = [
    NavItem("View Membership", "/", current_path == "/"),
    NavItem(
      "Edit Membership",
      "/membership/edit",
      current_path == "/membership/edit",
    ),
  ]

  case can_access_admin {
    True ->
      list.append(base_items, [NavItem("Admin dashboard", "/admin", False)])
    False -> base_items
  }
}
