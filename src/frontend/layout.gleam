import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn layout(elements: List(Element(t)), con_name: String) -> Element(t) {
  html.html([], [
    html.head([], [
      html.title([], con_name <> " registration system - kadreg"),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/" <> con_name <> ".css"),
      ]),
    ]),
    html.body([], elements),
  ])
}
