make_org_visnetwork <- function(graph, urad_zkr, igraph_layout) {

  htmlwidgets::setWidgetIdSeed(seed = 10, kind = NULL, normal.kind = NULL)

  orgdata_mini_edges <- extract_orgdata_edges_from_graph(graph, urad_zkratka == urad_zkr)
  orgdata_mini_nodes <- extract_orgdata_nodes_from_graph(graph, urad_zkratka == urad_zkr)

  color_palette <- c("black", "#1A1A1A", "#4D4D4D", "#7F7F7F", "#B3B3B3", "#CCCCCC") |> rev()

  vn_jednomini_base <- visNetwork(
    orgdata_mini_nodes |>
      mutate(nazev_show = paste0(nazev, "<br />", child_ftes, " osob"),
             value = if_else(dpth == 1, 0, child_ftes),
             dpth = dpth - 1,
             color0 = dpth,
             color0 = color_palette[dpth],
             title = nazev_show,
             color = if_else(color == "none", color0, color)),
    orgdata_mini_edges) |>
    visOptions(collapse = TRUE, highlightNearest = TRUE) |>
    visNodes() |>
    # visEdges(arrows = "to", smooth = TRUE) %>%
    visEdges(arrows = "none", smooth = list(enabled = TRUE, type = "cubicBezier")) |>
    visInteraction(zoomView = TRUE)

  if (!missing(igraph_layout)) {
    vn_jednomini <- vn_jednomini_base |>
      visIgraphLayout(layout = igraph_layout)
  }  else {
    vn_jednomini <- vn_jednomini_base |>
      visHierarchicalLayout(sortMethod = "directed",
                            direction = "LR",
                            nodeSpacing = 100,
                            shakeTowards = "roots",
                            parentCentralization = T,
                            levelSeparation = 1500)
  }
  vn_jednomini
}

