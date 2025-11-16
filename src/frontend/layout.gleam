import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub type IncludeTableJs {
  Tables
  NoTables
}

pub fn view(
  elements: List(Element(t)),
  con_name: String,
  include_table_js: IncludeTableJs,
) -> Element(t) {
  let head_elements = [
    html.title([], con_name <> " registration system - kadreg"),
    html.meta([
      attribute.name("viewport"),
      attribute.attribute("content", "width=device-width, initial-scale=1"),
    ]),
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/static/main.css"),
    ]),
  ]

  html.html([], [
    html.head([], case include_table_js {
      Tables -> [
        html.script(
          [
            attribute.src("/static/table.js"),
            attribute.attribute("defer", "true"),
          ],
          "",
        ),
        ..head_elements
      ]
      NoTables -> head_elements
    }),
    html.body([], elements),
  ])
}
