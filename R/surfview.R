#' @import htmlwidgets
#' @export
surfview <- function(vertices, indices, data, color_map,
                     curvature=NULL, width = NULL, height = NULL) {

  # pass the data and settings using 'x'
  x <- list(
    vertices = as.vector(vertices),
    indices = as.vector(indices)-1,
    data=data,
    color_map=color_map,
    curvature=curvature
  )

  # create the widget
  htmlwidgets::createWidget("threetest", x, width = width, height = height)
}
