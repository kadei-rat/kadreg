import gleam/int
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import models/members.{type MemberStats}

pub fn view(stats: MemberStats) -> Element(t) {
  html.div([], [
    html.div([attribute.class("stats-grid")], [
      stat_card(
        "Total Members",
        int.to_string(stats.total_members),
        "Active registered members",
      ),
      stat_card(
        "Recent Signups",
        int.to_string(stats.recent_signups),
        "New members in last 30 days",
      ),
      stat_card(
        "Staff Members",
        int.to_string(stats.total_staff),
        "Staff, RegStaff, Directors & Sysadmins",
      ),
      stat_card(
        "Deleted Members",
        int.to_string(stats.total_deleted),
        "Members who have been removed",
      ),
    ]),
  ])
}

fn stat_card(label: String, number: String, description: String) -> Element(t) {
  html.div([attribute.class("stat-card")], [
    html.div([attribute.class("stat-number")], [html.text(number)]),
    html.div([attribute.class("stat-label")], [html.text(label)]),
    html.div([attribute.class("stat-description")], [html.text(description)]),
  ])
}
